import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;
import 'package:uuid/uuid.dart';

import 'package:otpbridge/app/providers.dart';
import 'package:otpbridge/core/theme/app_colors.dart';
import 'package:otpbridge/core/theme/app_spacing.dart';
import 'package:otpbridge/core/widgets/widgets.dart';
import 'package:otpbridge/domain/models/models.dart';
import 'package:otpbridge/domain/services/contacts_service.dart';

/// What the contact picker resolved to. Callers switch on the subtype.
sealed class ContactPickerResult {
  const ContactPickerResult();
}

/// Single-pick mode: the user chose one contact (and, when the contact has
/// several numbers, one specific phone).
class ContactPicked extends ContactPickerResult {
  const ContactPicked({required this.name, required this.phone, this.email});

  final String name;
  final String phone;
  final String? email;
}

/// Multi-select mode: [recipients] were created and saved already.
class ContactsAdded extends ContactPickerResult {
  const ContactsAdded(this.recipients);

  final List<Recipient> recipients;
}

/// The user asked to type the details instead (permission denied, contacts
/// unsupported, or simply preference). Never a dead end.
class ManualEntryRequested extends ContactPickerResult {
  const ManualEntryRequested();
}

enum _PickerPhase { loading, unsupported, denied, ready }

/// In-app device-contact picker with search, initials avatars and an
/// always-available manual-entry fallback.
///
/// - Single mode (default): pops with a [ContactPicked].
/// - Multi mode: lets the user select several contacts, saves a [Recipient]
///   for each and pops with a [ContactsAdded].
class ContactPickerScreen extends ConsumerStatefulWidget {
  const ContactPickerScreen({
    super.key,
    this.multiSelect = false,
    this.maxSelectable,
  });

  /// Allow selecting several contacts and saving them all at once.
  final bool multiSelect;

  /// Cap on how many contacts can be selected in multi mode (free tier).
  /// Null = unlimited.
  final int? maxSelectable;

  /// Push the picker and await its result. Returns null when dismissed.
  static Future<ContactPickerResult?> pick(
    BuildContext context, {
    bool multiSelect = false,
    int? maxSelectable,
  }) {
    return Navigator.of(context).push<ContactPickerResult>(
      MaterialPageRoute(
        builder: (_) => ContactPickerScreen(
          multiSelect: multiSelect,
          maxSelectable: maxSelectable,
        ),
      ),
    );
  }

  @override
  ConsumerState<ContactPickerScreen> createState() =>
      _ContactPickerScreenState();
}

class _ContactPickerScreenState extends ConsumerState<ContactPickerScreen> {
  final _searchController = TextEditingController();
  _PickerPhase _phase = _PickerPhase.loading;
  List<DeviceContact> _contacts = const [];

  /// contact id → the phone number chosen for it (multi mode).
  final Map<String, String> _selectedPhones = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() => _phase = _PickerPhase.loading);
    final service = ref.read(contactsServiceProvider);
    if (!await service.isSupported()) {
      if (mounted) setState(() => _phase = _PickerPhase.unsupported);
      return;
    }
    final granted = await service.requestPermission();
    if (!granted) {
      if (mounted) setState(() => _phase = _PickerPhase.denied);
      return;
    }
    final contacts = await service.getAll();
    if (mounted) {
      setState(() {
        _contacts = contacts;
        _phase = _PickerPhase.ready;
      });
    }
  }

  static String _digits(String value) =>
      value.replaceAll(RegExp(r'[^0-9]'), '');

  List<DeviceContact> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _contacts;
    final queryDigits = _digits(query);
    return _contacts.where((c) {
      if (c.name.toLowerCase().contains(query)) return true;
      if (queryDigits.isEmpty) return false;
      return c.phones.any((p) => _digits(p).contains(queryDigits));
    }).toList();
  }

  void _finishManual() =>
      Navigator.of(context).pop(const ManualEntryRequested());

  /// Bottom sheet to pick one of a contact's several numbers.
  Future<String?> _choosePhone(DeviceContact contact) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) {
        final textTheme = Theme.of(sheetContext).textTheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.xs,
                  AppSpacing.screenH,
                  AppSpacing.xs,
                ),
                child: Text(
                  'Which number for ${contact.name}?',
                  style: textTheme.titleMedium,
                ),
              ),
              for (final phone in contact.phones)
                ListTile(
                  minTileHeight: AppSpacing.touchTarget,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenH),
                  leading: const Icon(Icons.phone_outlined, size: 20),
                  title: Text(phone),
                  onTap: () => Navigator.of(sheetContext).pop(phone),
                ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickSingle(DeviceContact contact) async {
    final phone = contact.phones.length == 1
        ? contact.phones.first
        : await _choosePhone(contact);
    if (phone == null || !mounted) return;
    Navigator.of(context).pop(
      ContactPicked(
        name: contact.name,
        phone: phone,
        email: contact.primaryEmail,
      ),
    );
  }

  Future<void> _toggle(DeviceContact contact) async {
    if (_selectedPhones.containsKey(contact.id)) {
      setState(() => _selectedPhones.remove(contact.id));
      return;
    }
    final max = widget.maxSelectable;
    if (max != null && _selectedPhones.length >= max) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Your plan allows $max more recipient${max == 1 ? '' : 's'} — '
              'upgrade for unlimited.',
            ),
          ),
        );
      return;
    }
    final phone = contact.phones.length == 1
        ? contact.phones.first
        : await _choosePhone(contact);
    if (phone == null || !mounted) return;
    setState(() => _selectedPhones[contact.id] = phone);
  }

  Future<void> _saveSelected() async {
    if (_saving || _selectedPhones.isEmpty) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(recipientsRepositoryProvider);
      final now = DateTime.now();
      final created = <Recipient>[];
      for (final contact in _contacts) {
        final phone = _selectedPhones[contact.id];
        if (phone == null) continue;
        final recipient = Recipient(
          id: const Uuid().v4(),
          name: contact.name,
          phone: phone,
          email: contact.primaryEmail,
          createdAt: now,
        );
        await repo.save(recipient);
        created.add(recipient);
      }
      if (mounted) Navigator.of(context).pop(ContactsAdded(created));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedPhones.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.multiSelect ? 'Add from contacts' : 'Choose a contact'),
      ),
      body: switch (_phase) {
        _PickerPhase.loading =>
          const Center(child: CircularProgressIndicator()),
        _PickerPhase.unsupported => _UnsupportedView(onManual: _finishManual),
        _PickerPhase.denied => _PermissionDeniedView(
            onOpenSettings: openAppSettings,
            onRetry: _init,
            onManual: _finishManual,
          ),
        _PickerPhase.ready => _buildList(context),
      },
      bottomNavigationBar: widget.multiSelect &&
              _phase == _PickerPhase.ready &&
              selectedCount > 0
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.sm,
                AppSpacing.screenH,
                AppSpacing.sm,
              ),
              child: FilledButton(
                onPressed: _saving ? null : _saveSelected,
                child: _saving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.tokens.onPrimary,
                        ),
                      )
                    : Text(
                        'Add $selectedCount '
                        'recipient${selectedCount == 1 ? '' : 's'}',
                      ),
              ),
            )
          : null,
    );
  }

  Widget _buildList(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    if (_contacts.isEmpty) {
      return EmptyState(
        icon: Icons.person_search_outlined,
        title: 'No contacts with phone numbers',
        message: 'You can still add a recipient by typing their details.',
        action: FilledButton.icon(
          onPressed: _finishManual,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, AppSpacing.touchTarget),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          ),
          icon: const Icon(Icons.edit_outlined, size: 20),
          label: const Text('Enter manually'),
        ),
      );
    }

    final filtered = _filtered;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.xs,
            AppSpacing.screenH,
            AppSpacing.xs,
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search name or number',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    ),
            ),
          ),
        ),
        if (widget.multiSelect)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              0,
              AppSpacing.screenH,
              AppSpacing.xxs,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Tap to select — you can pick several.',
                style: textTheme.bodySmall?.copyWith(color: t.textTertiary),
              ),
            ),
          ),
        Expanded(
          child: filtered.isEmpty
              ? EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No matches',
                  message: 'Try a different name or number, or type the '
                      'details instead.',
                  action: TextButton(
                    onPressed: _finishManual,
                    style: TextButton.styleFrom(
                      minimumSize:
                          const Size(0, AppSpacing.touchTarget),
                    ),
                    child: const Text('Enter manually'),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    AppSpacing.xxs,
                    AppSpacing.screenH,
                    AppSpacing.xxl,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: context.tokens.border,
                  ),
                  itemBuilder: (context, index) =>
                      _contactRow(context, filtered[index]),
                ),
        ),
      ],
    );
  }

  Widget _contactRow(BuildContext context, DeviceContact contact) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final selected = _selectedPhones.containsKey(contact.id);
    final phoneLabel = selected
        ? _selectedPhones[contact.id]!
        : (contact.primaryPhone ?? '');
    final extraPhones = contact.phones.length - 1;

    return InkWell(
      onTap: () =>
          widget.multiSelect ? _toggle(contact) : _pickSingle(contact),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? t.primary : t.primarySubtle,
                shape: BoxShape.circle,
              ),
              child: selected
                  ? Icon(Icons.check_rounded, size: 22, color: t.onPrimary)
                  : Text(
                      contact.initials,
                      style: textTheme.titleMedium?.copyWith(
                        color: t.onPrimarySubtle,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    extraPhones > 0 && !selected
                        ? '$phoneLabel · +$extraPhones more'
                        : phoneLabel,
                    style: textTheme.bodySmall
                        ?.copyWith(color: t.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            if (widget.multiSelect)
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 22,
                color: selected ? t.primary : t.textTertiary,
              )
            else
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: t.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// Friendly rationale when contact permission is denied — with an escape
/// hatch to system settings and the manual path.
class _PermissionDeniedView extends StatelessWidget {
  const _PermissionDeniedView({
    required this.onOpenSettings,
    required this.onRetry,
    required this.onManual,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onRetry;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.contacts_outlined,
      title: 'Allow access to contacts',
      message: 'OTPBridge only reads names and numbers so you can pick a '
          'recipient without typing. Nothing leaves your phone.',
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.icon(
            onPressed: onOpenSettings,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, AppSpacing.touchTarget),
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            ),
            icon: const Icon(Icons.settings_outlined, size: 20),
            label: const Text('Open settings'),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, AppSpacing.touchTarget),
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            ),
            child: const Text('Try again'),
          ),
          const SizedBox(height: AppSpacing.xxs),
          TextButton(
            onPressed: onManual,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, AppSpacing.touchTarget),
            ),
            child: const Text('Enter details manually'),
          ),
        ],
      ),
    );
  }
}

/// Shown on platforms without an address book (emulator, desktop, iOS
/// companion) — the manual path always works.
class _UnsupportedView extends StatelessWidget {
  const _UnsupportedView({required this.onManual});

  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.contact_page_outlined,
      title: 'Contacts aren’t available here',
      message: 'On this device you can add recipients by typing their '
          'details instead.',
      action: FilledButton.icon(
        onPressed: onManual,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        ),
        icon: const Icon(Icons.edit_outlined, size: 20),
        label: const Text('Enter manually'),
      ),
    );
  }
}
