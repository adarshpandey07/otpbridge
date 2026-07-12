import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:otpbridge/app/providers.dart';
import 'package:otpbridge/app/router.dart';
import 'package:otpbridge/core/theme/app_colors.dart';
import 'package:otpbridge/core/theme/app_spacing.dart';
import 'package:otpbridge/core/widgets/widgets.dart';
import 'package:otpbridge/domain/models/models.dart';
import 'package:otpbridge/features/manual_forward/manual_forward_screen.dart';
import 'package:otpbridge/features/security/pin_setup_screen.dart';
import 'package:otpbridge/features/security/sms_consent_sheet.dart';
import 'package:otpbridge/features/settings/widgets/setting_tile.dart';

/// App settings: forwarding, security, banking, appearance, subscription,
/// data & privacy, about. Every change persists immediately.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static final NumberFormat _rupees =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).valueOrNull;
    final subscription = ref.watch(subscriptionProvider).valueOrNull;
    final recipients =
        ref.watch(recipientsProvider).valueOrNull ?? const <Recipient>[];

    if (settings == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.xs,
          AppSpacing.screenH,
          AppSpacing.xxl,
        ),
        children: [
          _forwardingGroup(context, ref, settings, recipients),
          const SizedBox(height: AppSpacing.xl),
          _securityGroup(context, ref, settings),
          const SizedBox(height: AppSpacing.xl),
          _bankingGroup(context, ref, settings, subscription),
          const SizedBox(height: AppSpacing.xl),
          _appearanceGroup(context, ref, settings),
          const SizedBox(height: AppSpacing.xl),
          _subscriptionGroup(context, subscription),
          const SizedBox(height: AppSpacing.xl),
          _dataGroup(context, ref, settings),
          const SizedBox(height: AppSpacing.xl),
          _aboutGroup(context),
        ],
      ),
    );
  }

  Future<void> _save(WidgetRef ref, AppSettings updated) =>
      ref.read(settingsRepositoryProvider).save(updated);

  // ── Forwarding ───────────────────────────────────────────────────────────

  Widget _forwardingGroup(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
    List<Recipient> recipients,
  ) {
    final defaultRecipient = recipients
        .where((r) => r.id == settings.defaultRecipientId)
        .firstOrNull;

    return SettingsGroup(
      title: 'Forwarding',
      children: [
        SettingSwitch(
          icon: Icons.sms_outlined,
          title: 'SMS listening',
          subtitle: settings.listeningEnabled
              ? 'Watching for incoming OTPs'
              : 'Paused — no messages are read',
          value: settings.listeningEnabled,
          onChanged: (v) => _toggleListening(context, ref, settings, v),
        ),
        SettingTile(
          icon: Icons.outbox_outlined,
          title: 'Forward an OTP manually',
          subtitle: 'Paste a code and send it — no SMS permission needed',
          trailing: const SettingChevron(),
          onTap: () => openManualForward(context),
        ),
        SettingTile(
          icon: Icons.person_pin_circle_outlined,
          title: 'Default recipient',
          subtitle: defaultRecipient?.name ?? 'Not set',
          trailing: const SettingChevron(),
          onTap: () =>
              _pickDefaultRecipient(context, ref, settings, recipients),
        ),
        SettingTile(
          icon: Icons.group_outlined,
          title: 'Manage recipients',
          subtitle: recipients.isEmpty
              ? 'No recipients yet'
              : '${recipients.length} recipient${recipients.length == 1 ? '' : 's'}',
          trailing: const SettingChevron(),
          onTap: () => context.push(Routes.recipients),
        ),
      ],
    );
  }

  Future<void> _toggleListening(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
    bool enabled,
  ) async {
    // Turning ON reads incoming SMS — show the prominent disclosure first and
    // only proceed when the user explicitly allows. Turning OFF is immediate.
    if (enabled) {
      final consented = await showSmsConsent(context);
      if (!consented) return;
    }
    await _save(ref, settings.copyWith(listeningEnabled: enabled));
    // Best-effort: keep the native service in sync; never block the toggle.
    try {
      final gateway = ref.read(smsGatewayProvider);
      if (enabled) {
        await gateway.startListening();
      } else {
        await gateway.stopListening();
      }
    } catch (_) {
      // Companion platforms have no service to control.
    }
  }

  Future<void> _pickDefaultRecipient(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
    List<Recipient> recipients,
  ) {
    final t = context.tokens;
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        Widget check(bool selected) => Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? t.primary : t.textTertiary,
            );

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.xs,
                  AppSpacing.screenH,
                  AppSpacing.xs,
                ),
                child: SectionHeader(
                  title: 'Default recipient',
                  subtitle: 'Used when a rule has no recipient of its own',
                  padding: EdgeInsets.zero,
                ),
              ),
              if (recipients.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.screenH),
                  child: EmptyState(
                    icon: Icons.person_add_alt_outlined,
                    title: 'No recipients yet',
                    message: 'Add someone you trust to forward OTPs to.',
                    action: FilledButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        context.push(Routes.recipients);
                      },
                      child: const Text('Add recipient'),
                    ),
                  ),
                )
              else ...[
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenH),
                  leading: Icon(Icons.block_outlined, color: t.textTertiary),
                  title: const Text('No default'),
                  trailing: check(settings.defaultRecipientId == null),
                  onTap: () {
                    _save(ref,
                        settings.copyWith(clearDefaultRecipient: true));
                    Navigator.of(sheetContext).pop();
                  },
                ),
                for (final r in recipients)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenH),
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: t.primarySubtle,
                      child: Text(
                        r.initials,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: t.onPrimarySubtle,
                        ),
                      ),
                    ),
                    title: Text(r.name),
                    subtitle: Text(r.phone),
                    trailing: check(settings.defaultRecipientId == r.id),
                    onTap: () {
                      _save(ref,
                          settings.copyWith(defaultRecipientId: r.id));
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                const SizedBox(height: AppSpacing.xs),
              ],
            ],
          ),
        );
      },
    );
  }

  // ── Security ─────────────────────────────────────────────────────────────

  /// Auto-lock timeout choices: minutes → label.
  static const List<(int, String)> _autoLockChoices = [
    (0, 'Immediately'),
    (1, 'After 1 minute'),
    (5, 'After 5 minutes'),
    (30, 'After 30 minutes'),
  ];

  static String _autoLockLabel(int minutes) {
    for (final (value, label) in _autoLockChoices) {
      if (value == minutes) return label;
    }
    return 'After $minutes minutes';
  }

  Widget _securityGroup(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    final lockOn = settings.appLockEnabled;

    return SettingsGroup(
      title: 'Security',
      children: [
        SettingSwitch(
          icon: Icons.lock_outline_rounded,
          title: 'App lock',
          subtitle: lockOn
              ? 'PIN required when opening the app'
              : 'Protect the app with a 4-digit PIN',
          value: lockOn,
          onChanged: (v) => _toggleAppLock(context, ref, settings, v),
        ),
        if (lockOn) ...[
          SettingTile(
            icon: Icons.password_rounded,
            title: 'Change PIN',
            subtitle: 'Verify your current PIN, then pick a new one',
            trailing: const SettingChevron(),
            onTap: () => _changePin(context),
          ),
          SettingTile(
            icon: Icons.lock_clock_outlined,
            title: 'Auto-lock',
            subtitle: _autoLockLabel(settings.appLockAfterMinutes),
            trailing: const SettingChevron(),
            onTap: () => _pickAutoLock(context, ref, settings),
          ),
          SettingSwitch(
            icon: Icons.fingerprint_rounded,
            title: 'Unlock with biometric',
            subtitle: 'Use fingerprint or face instead of your PIN',
            value: settings.biometricEnabled,
            onChanged: (v) => _toggleBiometric(context, ref, settings, v),
          ),
          SettingTile(
            icon: Icons.lock_person_outlined,
            title: 'Lock now',
            subtitle: 'Cover the app with the lock screen',
            onTap: () =>
                ref.read(appLockControllerProvider.notifier).lockNow(),
          ),
        ],
        SettingSwitch(
          icon: Icons.visibility_off_outlined,
          title: 'Mask OTP in notifications',
          subtitle: 'Show •••••• instead of the code',
          value: settings.maskOtpInNotifications,
          onChanged: (v) =>
              _save(ref, settings.copyWith(maskOtpInNotifications: v)),
        ),
      ],
    );
  }

  Future<void> _toggleAppLock(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
    bool enabled,
  ) async {
    if (enabled) {
      // A PIN must exist before the lock can be armed.
      final hasPin = await ref.read(pinStoreProvider).hasPin();
      if (!hasPin) {
        if (!context.mounted) return;
        final created = await setupPin(context);
        if (!created) return; // Cancelled — leave the switch off.
      }
      await _save(ref, settings.copyWith(appLockEnabled: true));
      return;
    }

    final confirmed = await _confirm(
      context,
      title: 'Turn off app lock?',
      message: 'Your PIN will be removed and OTPBridge will open '
          'without asking you to unlock.',
      confirmLabel: 'Turn off',
    );
    if (!confirmed) return;
    await ref.read(pinStoreProvider).clear();
    await _save(
      ref,
      settings.copyWith(appLockEnabled: false, biometricEnabled: false),
    );
  }

  Future<void> _changePin(BuildContext context) async {
    final changed = await setupPin(context, change: true);
    if (changed && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN updated')),
      );
    }
  }

  Future<void> _pickAutoLock(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    final t = context.tokens;
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.xs,
                  AppSpacing.screenH,
                  AppSpacing.xs,
                ),
                child: SectionHeader(
                  title: 'Auto-lock',
                  subtitle: 'How soon the app locks after you leave it',
                  padding: EdgeInsets.zero,
                ),
              ),
              for (final (minutes, label) in _autoLockChoices)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenH),
                  leading: Icon(
                    minutes == 0 ? Icons.bolt_outlined : Icons.timer_outlined,
                    color: t.textSecondary,
                  ),
                  title: Text(label),
                  trailing: Icon(
                    settings.appLockAfterMinutes == minutes
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: settings.appLockAfterMinutes == minutes
                        ? t.primary
                        : t.textTertiary,
                  ),
                  onTap: () {
                    _save(ref,
                        settings.copyWith(appLockAfterMinutes: minutes));
                    Navigator.of(sheetContext).pop();
                  },
                ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleBiometric(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
    bool enabled,
  ) async {
    if (!enabled) {
      await _save(ref, settings.copyWith(biometricEnabled: false));
      return;
    }
    final bio = ref.read(biometricAuthProvider);
    if (!await bio.isAvailable()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No fingerprint or face is set up on this device'),
        ));
      }
      return;
    }
    final ok = await bio.authenticate(
      reason: 'Confirm to enable biometric unlock',
    );
    if (ok) {
      await _save(ref, settings.copyWith(biometricEnabled: true));
    }
  }

  // ── Banking ──────────────────────────────────────────────────────────────

  Widget _bankingGroup(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
    SubscriptionState? subscription,
  ) {
    final canCustomizeCap =
        subscription?.limits.canCustomizeBankingCap ?? false;

    return SettingsGroup(
      title: 'Banking',
      children: [
        SettingTile(
          icon: Icons.currency_rupee_rounded,
          title: 'Auto-forward cap',
          subtitle: canCustomizeCap
              ? 'Amounts above ${_rupees.format(settings.bankingAutoForwardCap)} need approval'
              : 'Fixed at ${_rupees.format(settings.bankingAutoForwardCap)} on the free plan',
          trailing: canCustomizeCap
              ? const SettingChevron()
              : const StatusPill(
                  label: 'Premium',
                  tone: PillTone.primary,
                  icon: Icons.lock_outline_rounded,
                  dense: true,
                ),
          onTap: canCustomizeCap
              ? () => _editBankingCap(context, ref, settings)
              : () => context.push(Routes.paywall),
        ),
        SettingSwitch(
          icon: Icons.gpp_maybe_outlined,
          title: 'High-risk OTPs require approval',
          subtitle: 'Banking, UPI and card OTPs wait for you',
          value: settings.highRiskRequiresApproval,
          onChanged: (v) =>
              _save(ref, settings.copyWith(highRiskRequiresApproval: v)),
        ),
        _approvalTimeoutTile(context, ref, settings),
      ],
    );
  }

  Widget _approvalTimeoutTile(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    final t = context.tokens;
    final minutes = settings.approvalTtlMinutes;

    return SettingTile(
      icon: Icons.timer_outlined,
      title: 'Approval timeout',
      subtitle: 'Pending OTPs expire after $minutes min',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: minutes > 1
                ? () => _save(
                    ref, settings.copyWith(approvalTtlMinutes: minutes - 1))
                : null,
            icon: const Icon(Icons.remove_circle_outline_rounded),
            color: t.textSecondary,
            tooltip: 'Decrease',
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$minutes',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            onPressed: minutes < 30
                ? () => _save(
                    ref, settings.copyWith(approvalTtlMinutes: minutes + 1))
                : null,
            icon: const Icon(Icons.add_circle_outline_rounded),
            color: t.textSecondary,
            tooltip: 'Increase',
          ),
        ],
      ),
    );
  }

  Future<void> _editBankingCap(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final controller = TextEditingController(
      text: settings.bankingAutoForwardCap.toStringAsFixed(0),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Auto-forward cap'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Financial OTPs above this amount always wait for your approval.',
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                prefixText: '₹ ',
                hintText: '5000',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext)
                .pop(double.tryParse(controller.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result > 0) {
      await _save(ref, settings.copyWith(bankingAutoForwardCap: result));
    }
  }

  // ── Appearance ───────────────────────────────────────────────────────────

  Widget _appearanceGroup(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    final t = context.tokens;
    return SettingsGroup(
      title: 'Appearance',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: t.surfaceSunken,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(Icons.contrast_rounded,
                        size: 20, color: t.textSecondary),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Theme',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                      icon: Icon(Icons.brightness_auto_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode_outlined, size: 18),
                    ),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (selection) =>
                      _save(ref, settings.copyWith(themeMode: selection.first)),
                  style: ButtonStyle(
                    side: WidgetStatePropertyAll(BorderSide(color: t.border)),
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? t.primarySubtle
                          : Colors.transparent,
                    ),
                    foregroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? t.onPrimarySubtle
                          : t.textSecondary,
                    ),
                    textStyle: WidgetStatePropertyAll(
                      Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Subscription ─────────────────────────────────────────────────────────

  Widget _subscriptionGroup(
    BuildContext context,
    SubscriptionState? subscription,
  ) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final isPremium = subscription?.tier == SubscriptionTier.premium;
    final limits = subscription?.limits ?? TierLimits.free;
    final used = subscription?.forwardsUsed ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Subscription',
          padding:
              EdgeInsets.only(left: AppSpacing.xxs, bottom: AppSpacing.xs),
        ),
        GlassCard(
          onTap: () => context.push(Routes.paywall),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: t.primarySubtle,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(Icons.workspace_premium_outlined,
                        size: 22, color: t.onPrimarySubtle),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isPremium ? 'Premium' : 'Free plan',
                            style: text.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          isPremium
                              ? 'Unlimited forwards · all features'
                              : '$used of ${limits.monthlyForwards} forwards used this month',
                          style: text.bodySmall
                              ?.copyWith(color: t.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  StatusPill(
                    label: isPremium ? 'Manage' : 'Upgrade',
                    tone: isPremium ? PillTone.neutral : PillTone.primary,
                  ),
                ],
              ),
              if (!isPremium) ...[
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: limits.monthlyForwards <= 0
                        ? 0
                        : (used / limits.monthlyForwards).clamp(0.0, 1.0),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Data & privacy ───────────────────────────────────────────────────────

  Widget _dataGroup(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    return SettingsGroup(
      title: 'Data & privacy',
      children: [
        SettingTile(
          icon: Icons.ios_share_rounded,
          title: 'Export history',
          subtitle: 'Save your forwarding log',
          trailing: const SettingChevron(),
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Export is coming soon')),
          ),
        ),
        SettingTile(
          icon: Icons.science_outlined,
          title: 'Load sample data',
          subtitle: 'Populate demo rules, recipients & history',
          onTap: () => _loadSampleData(context, ref),
        ),
        SettingTile(
          icon: Icons.delete_sweep_outlined,
          title: 'Clear history',
          subtitle: 'Remove all recorded activity',
          onTap: () => _clearHistory(context, ref),
        ),
        SettingTile(
          icon: Icons.restart_alt_rounded,
          title: 'Reset app',
          subtitle: 'Restore defaults and start over',
          destructive: true,
          onTap: () => _resetApp(context, ref),
        ),
      ],
    );
  }

  Future<void> _loadSampleData(BuildContext context, WidgetRef ref) async {
    await ref.read(sampleDataProvider).load();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sample data loaded')),
      );
    }
  }

  Future<void> _clearHistory(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      title: 'Clear history?',
      message:
          'All recorded OTP activity will be removed. This cannot be undone.',
      confirmLabel: 'Clear',
    );
    if (!confirmed) return;
    await ref.read(historyRepositoryProvider).clear();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('History cleared')),
      );
    }
  }

  Future<void> _resetApp(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      title: 'Reset OTPBridge?',
      message: 'Settings return to defaults and history is erased. '
          'You will go through setup again.',
      confirmLabel: 'Reset',
    );
    if (!confirmed) return;
    // Full wipe: every encrypted box (rules, recipients, history, queue,
    // approvals, suggestions, settings, subscription) + the lock PIN.
    await ref.read(localStoreProvider).wipeAll();
    await ref.read(pinStoreProvider).clear();
    await ref.read(settingsRepositoryProvider).save(const AppSettings());
    if (context.mounted) context.go(Routes.onboarding);
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final t = context.tokens;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: t.danger,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── About ────────────────────────────────────────────────────────────────

  Widget _aboutGroup(BuildContext context) {
    return SettingsGroup(
      title: 'About',
      children: const [
        SettingTile(
          icon: Icons.info_outline_rounded,
          title: 'Version',
          subtitle: '1.0.0 (build 1)',
        ),
        SettingTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy',
          subtitle: 'Messages are read and classified on your device, stored '
              'AES-encrypted, and never sold or shared. Only the OTPs you '
              'approve ever leave your phone.',
        ),
      ],
    );
  }
}
