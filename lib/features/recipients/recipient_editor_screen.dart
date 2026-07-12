import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:otpbridge/app/providers.dart';
import 'package:otpbridge/core/theme/app_colors.dart';
import 'package:otpbridge/core/theme/app_spacing.dart';
import 'package:otpbridge/core/widgets/widgets.dart';
import 'package:otpbridge/domain/models/models.dart';
import 'package:otpbridge/features/recipients/contact_picker_screen.dart';

/// Create or edit a [Recipient]. Pass null to create a new one.
/// For new recipients the primary path is picking from device contacts;
/// manual entry stays available as the fallback.
/// Only SMS ships in v1 — other channels are shown as coming soon.
class RecipientEditorScreen extends ConsumerStatefulWidget {
  const RecipientEditorScreen({super.key, this.recipient});

  final Recipient? recipient;

  @override
  ConsumerState<RecipientEditorScreen> createState() =>
      _RecipientEditorScreenState();
}

class _RecipientEditorScreenState
    extends ConsumerState<RecipientEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late ForwardChannel _channel;
  bool _saving = false;
  bool _contactsSupported = false;

  bool get _isEditing => widget.recipient != null;

  static IconData _channelIcon(ForwardChannel channel) => switch (channel) {
        ForwardChannel.sms => Icons.sms_outlined,
        ForwardChannel.whatsapp => Icons.chat_outlined,
        ForwardChannel.telegram => Icons.send_outlined,
        ForwardChannel.email => Icons.alternate_email_rounded,
        ForwardChannel.push => Icons.notifications_none_rounded,
      };

  @override
  void initState() {
    super.initState();
    final recipient = widget.recipient;
    _nameController = TextEditingController(text: recipient?.name ?? '');
    _phoneController = TextEditingController(text: recipient?.phone ?? '');
    _emailController = TextEditingController(text: recipient?.email ?? '');
    _channel = recipient?.preferredChannel ?? ForwardChannel.sms;
    if (!_isEditing) _checkContactsSupport();
  }

  Future<void> _checkContactsSupport() async {
    final supported = await ref.read(contactsServiceProvider).isSupported();
    if (mounted && supported) setState(() => _contactsSupported = true);
  }

  Future<void> _pickFromContacts() async {
    final result = await ContactPickerScreen.pick(context);
    if (!mounted) return;
    if (result is ContactPicked) {
      setState(() {
        _nameController.text = result.name;
        _phoneController.text = result.phone;
        final email = result.email;
        if (email != null && email.isNotEmpty) _emailController.text = email;
      });
    }
    // ManualEntryRequested → we're already on the manual form.
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return 'Enter a phone number';
    if (!RegExp(r'^\+?[0-9()\-\s]+$').hasMatch(raw)) {
      return 'Enter a valid phone number';
    }
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 7 || digits.length > 15) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(raw)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      final email = _emailController.text.trim();
      final recipient = Recipient(
        id: widget.recipient?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: email.isEmpty ? null : email,
        preferredChannel: _channel,
        groupIds: widget.recipient?.groupIds ?? const [],
        createdAt: widget.recipient?.createdAt ?? DateTime.now(),
      );
      await ref.read(recipientsRepositoryProvider).save(recipient);
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final recipient = widget.recipient!;
    final t = context.tokens;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete recipient?'),
        content: Text(
          '“${recipient.name}” will be removed. Rules that forward to them '
          'will stop delivering.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: t.danger,
              foregroundColor: Theme.of(context).colorScheme.onError,
              minimumSize: const Size(0, AppSpacing.touchTarget),
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(recipientsRepositoryProvider).remove(recipient.id);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit recipient' : 'New recipient'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Delete recipient',
              onPressed: _delete,
              icon: Icon(Icons.delete_outline_rounded, color: t.danger),
            ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.xs,
            AppSpacing.screenH,
            AppSpacing.xxl,
          ),
          children: [
            if (!_isEditing && _contactsSupported) ...[
              _ContactsCta(onTap: _pickFromContacts),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(child: Divider(color: t.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm),
                    child: Text(
                      'or enter manually',
                      style: textTheme.bodySmall
                          ?.copyWith(color: t.textTertiary),
                    ),
                  ),
                  Expanded(child: Divider(color: t.border)),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Rahul Sharma',
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Enter a name'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                hintText: '+91 98765 43210',
              ),
              validator: _validatePhone,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Email (optional)',
                hintText: 'name@example.com',
              ),
              validator: _validateEmail,
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text('Preferred channel', style: textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final channel in ForwardChannel.values)
                  ChoiceChip(
                    avatar: Icon(
                      _channelIcon(channel),
                      size: 16,
                      color: _channel == channel
                          ? t.onPrimarySubtle
                          : t.textTertiary,
                    ),
                    label: Text(
                      channel == ForwardChannel.sms
                          ? channel.label
                          : '${channel.label} · Soon',
                    ),
                    selected: _channel == channel,
                    showCheckmark: false,
                    onSelected: channel == ForwardChannel.sms
                        ? (v) {
                            if (v) setState(() => _channel = channel);
                          }
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'OTPs are forwarded over SMS today. WhatsApp, Telegram, email '
              'and push are coming soon.',
              style: textTheme.bodySmall?.copyWith(color: t.textTertiary),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.sm,
          AppSpacing.screenH,
          AppSpacing.sm,
        ),
        child: FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: t.onPrimary,
                  ),
                )
              : Text(_isEditing ? 'Save changes' : 'Add recipient'),
        ),
      ),
    );
  }
}

/// Primary path for a new recipient: pick from the device address book so
/// name, number and email fill in automatically.
class _ContactsCta extends StatelessWidget {
  const _ContactsCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: t.borderStrong,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.primarySubtle,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.contacts_outlined,
                size: 24, color: t.onPrimarySubtle),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choose from contacts', style: textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'Name and number fill in automatically',
                  style:
                      textTheme.bodySmall?.copyWith(color: t.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(Icons.chevron_right_rounded, size: 22, color: t.textTertiary),
        ],
      ),
    );
  }
}
