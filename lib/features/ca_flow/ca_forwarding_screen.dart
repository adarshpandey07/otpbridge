import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:otpbridge/app/providers.dart';
import 'package:otpbridge/app/router.dart';
import 'package:otpbridge/core/theme/app_colors.dart';
import 'package:otpbridge/core/theme/app_spacing.dart';
import 'package:otpbridge/core/widgets/widgets.dart';
import 'package:otpbridge/domain/models/models.dart';
import 'package:otpbridge/features/recipients/contact_picker_screen.dart';

/// Push the guided "forward financial messages to my accountant" flow.
/// Call from anywhere (settings tile, dashboard card, FAB…).
void openCaFlow(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const CaForwardingScreen()),
  );
}

/// Duration presets for the delegation window.
enum _CaDuration { today, oneWeek, oneMonth, untilOff }

extension on _CaDuration {
  String get label => switch (this) {
        _CaDuration.today => 'Today',
        _CaDuration.oneWeek => 'One week',
        _CaDuration.oneMonth => 'One month',
        _CaDuration.untilOff => 'Until I turn it off',
      };

  IconData get icon => switch (this) {
        _CaDuration.today => Icons.today_outlined,
        _CaDuration.oneWeek => Icons.date_range_outlined,
        _CaDuration.oneMonth => Icons.calendar_month_outlined,
        _CaDuration.untilOff => Icons.all_inclusive_rounded,
      };

  /// Snackbar phrase, e.g. "…will go to Ramesh for 1 month."
  String get phrase => switch (this) {
        _CaDuration.today => 'for the rest of today',
        _CaDuration.oneWeek => 'for 1 week',
        _CaDuration.oneMonth => 'for 1 month',
        _CaDuration.untilOff => 'until you turn it off',
      };

  /// Last active day (inclusive). Null = never expires.
  DateTime? expiryFrom(DateTime now) => switch (this) {
        _CaDuration.today => DateTime(now.year, now.month, now.day),
        _CaDuration.oneWeek => now.add(const Duration(days: 7)),
        _CaDuration.oneMonth => DateTime(now.year, now.month + 1, now.day),
        _CaDuration.untilOff => null,
      };
}

/// Guided, minimal flow that creates ONE time-boxed [ForwardRule] sending
/// financial messages to an accountant. Steps: intro → recipient →
/// duration → confirm. Safe default: every message asks for approval.
class CaForwardingScreen extends ConsumerStatefulWidget {
  const CaForwardingScreen({super.key});

  @override
  ConsumerState<CaForwardingScreen> createState() =>
      _CaForwardingScreenState();
}

class _CaForwardingScreenState extends ConsumerState<CaForwardingScreen> {
  static const _stepCount = 4;

  /// The financial set this rule covers. Banking-login OTPs are opt-in.
  static const Set<OtpCategory> _financialCategories = {
    OtpCategory.bankingTransaction,
    OtpCategory.upi,
    OtpCategory.creditCard,
    OtpCategory.debitCard,
    OtpCategory.tax,
    OtpCategory.investment,
  };

  final _pageController = PageController();
  int _step = 0;
  String? _recipientId;
  _CaDuration _duration = _CaDuration.oneMonth;
  bool _requireApproval = true;
  bool _includeBankingLogin = false;
  bool _saving = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Recipient? get _selectedRecipient {
    final recipients =
        ref.read(recipientsProvider).valueOrNull ?? const <Recipient>[];
    return recipients.firstWhereOrNull((r) => r.id == _recipientId);
  }

  bool get _atRecipientCap {
    final recipients =
        ref.read(recipientsProvider).valueOrNull ?? const <Recipient>[];
    final subscription = ref.read(subscriptionProvider).valueOrNull;
    if (subscription == null ||
        subscription.tier != SubscriptionTier.free) {
      return false;
    }
    final limits = subscription.limits;
    return limits.maxRecipients >= 0 &&
        recipients.length >= limits.maxRecipients;
  }

  bool get _canContinue => switch (_step) {
        1 => _recipientId != null,
        3 => _selectedRecipient != null && !_saving,
        _ => true,
      };

  String get _ctaLabel => switch (_step) {
        0 => 'Get started',
        3 => 'Turn on forwarding',
        _ => 'Continue',
      };

  void _goToStep(int step) {
    _pageController.animateToPage(
      step,
      duration: AppMotion.base,
      curve: AppMotion.enter,
    );
    setState(() => _step = step);
  }

  void _back() {
    if (_step > 0) {
      _goToStep(_step - 1);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _next() {
    if (_step < _stepCount - 1) {
      _goToStep(_step + 1);
    } else {
      _save();
    }
  }

  static String _digits(String value) =>
      value.replaceAll(RegExp(r'[^0-9]'), '');

  /// Add the accountant via the shared contact picker. Reuses an existing
  /// recipient when the number matches; respects the free-tier cap.
  Future<void> _addFromContacts() async {
    final result = await ContactPickerScreen.pick(context);
    if (!mounted || result == null) return;

    if (result is ManualEntryRequested) {
      await _addManually();
      return;
    }
    if (result is! ContactPicked) return;

    final existing =
        ref.read(recipientsProvider).valueOrNull ?? const <Recipient>[];
    final pickedDigits = _digits(result.phone);
    final match = existing.firstWhereOrNull(
      (r) => pickedDigits.isNotEmpty && _digits(r.phone) == pickedDigits,
    );
    if (match != null) {
      setState(() => _recipientId = match.id);
      return;
    }
    if (_atRecipientCap) {
      if (mounted) context.push(Routes.paywall);
      return;
    }
    final recipient = Recipient(
      id: const Uuid().v4(),
      name: result.name,
      phone: result.phone,
      email: result.email,
      createdAt: DateTime.now(),
    );
    await ref.read(recipientsRepositoryProvider).save(recipient);
    if (mounted) setState(() => _recipientId = recipient.id);
  }

  /// Manual fallback: open the recipient editor, then auto-select whoever
  /// was just added.
  Future<void> _addManually() async {
    if (_atRecipientCap) {
      context.push(Routes.paywall);
      return;
    }
    final before =
        (ref.read(recipientsProvider).valueOrNull ?? const <Recipient>[])
            .map((r) => r.id)
            .toSet();
    await context.push(Routes.recipientEditor);
    if (!mounted) return;
    final after = await ref.read(recipientsRepositoryProvider).getAll();
    final added = after.firstWhereOrNull((r) => !before.contains(r.id));
    if (added != null && mounted) setState(() => _recipientId = added.id);
  }

  Future<void> _save() async {
    if (_saving) return;
    final recipient = _selectedRecipient;
    if (recipient == null) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(rulesRepositoryProvider);
      final existing = await repo.getAll(); // sorted by sortOrder
      final sortOrder =
          existing.isEmpty ? 0 : existing.last.sortOrder + 1;
      final now = DateTime.now();
      final expiry = _duration.expiryFrom(now);
      final schedule = expiry == null
          ? const RuleSchedule(kind: ScheduleKind.always)
          : RuleSchedule(
              kind: ScheduleKind.dateRange,
              fromDate: now,
              toDate: expiry,
            );

      final rule = ForwardRule(
        id: const Uuid().v4(),
        name: 'Financial → CA',
        sortOrder: sortOrder,
        categories: {
          ..._financialCategories,
          if (_includeBankingLogin) OtpCategory.bankingLogin,
        },
        schedule: schedule,
        action: _requireApproval
            ? RuleAction.requireApproval
            : RuleAction.forward,
        recipientIds: [recipient.id],
        createdAt: now,
      );
      await repo.save(rule);
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Financial messages will go to ${recipient.name} '
              '${_duration.phrase}.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _back,
          ),
          title: const Text('Accountant forwarding'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: _StepDots(step: _step, count: _stepCount),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildIntroStep(context),
                  _buildRecipientStep(context),
                  _buildDurationStep(context),
                  _buildConfirmStep(context),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.sm,
            AppSpacing.screenH,
            AppSpacing.sm,
          ),
          child: FilledButton(
            onPressed: _canContinue ? _next : null,
            child: _saving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: t.onPrimary,
                    ),
                  )
                : Text(_ctaLabel),
          ),
        ),
      ),
    );
  }

  // ── Step 1: intro ─────────────────────────────────────────────────────

  Widget _buildIntroStep(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        AppSpacing.xxl,
      ),
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.primarySubtle,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Icon(Icons.currency_rupee_rounded,
              size: 30, color: t.onPrimarySubtle),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Forward financial messages to your accountant',
          style: textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Your CA sees the transaction messages they need — bank debits '
          'and credits, UPI alerts, card charges, tax and investment '
          'updates — without you forwarding anything by hand.',
          style: textTheme.bodyMedium?.copyWith(color: t.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final category in _financialCategories)
              StatusPill(label: category.label, icon: category.icon),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        GlassCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_user_outlined, size: 22, color: t.success),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('You stay in control',
                        style: textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'By default each message waits for your approval '
                      'before it is sent, and the rule can expire on its '
                      'own. Turn it off anytime from Rules.',
                      style: textTheme.bodySmall
                          ?.copyWith(color: t.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 2: recipient ─────────────────────────────────────────────────

  Widget _buildRecipientStep(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final recipientsAsync = ref.watch(recipientsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        AppSpacing.xxl,
      ),
      children: [
        Text('Who should receive them?', style: textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Pick your accountant, or add them from your contacts.',
          style: textTheme.bodyMedium?.copyWith(color: t.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        ...recipientsAsync.when(
          loading: () => const [
            SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (error, _) => [
            GlassCard(
              child: Text(
                'Couldn’t load recipients.',
                style:
                    textTheme.bodyMedium?.copyWith(color: t.textSecondary),
              ),
            ),
          ],
          data: (recipients) => [
            for (final recipient in recipients) ...[
              _RecipientOption(
                recipient: recipient,
                selected: recipient.id == _recipientId,
                onTap: () =>
                    setState(() => _recipientId = recipient.id),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (recipients.isEmpty) ...[
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('No recipients yet', style: textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Add your accountant once — OTPBridge remembers them '
                      'for future rules.',
                      style: textTheme.bodySmall
                          ?.copyWith(color: t.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            OutlinedButton.icon(
              onPressed: _addFromContacts,
              style: OutlinedButton.styleFrom(
                minimumSize:
                    const Size.fromHeight(AppSpacing.touchTarget),
              ),
              icon: const Icon(Icons.contacts_outlined, size: 20),
              label: const Text('Add from contacts'),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: _addManually,
              style: TextButton.styleFrom(
                minimumSize:
                    const Size.fromHeight(AppSpacing.touchTarget),
              ),
              child: const Text('Enter details manually'),
            ),
          ],
        ),
      ],
    );
  }

  // ── Step 3: duration ──────────────────────────────────────────────────

  Widget _buildDurationStep(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();
    final dateFormat = DateFormat('d MMM');

    String sublabel(_CaDuration duration) {
      final expiry = duration.expiryFrom(now);
      return switch (duration) {
        _CaDuration.today => 'Stops automatically at midnight',
        _CaDuration.untilOff => 'Runs until you disable it in Rules',
        _ => 'Expires on ${dateFormat.format(expiry!)} — nothing to '
            'remember',
      };
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        AppSpacing.xxl,
      ),
      children: [
        Text('For how long?', style: textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Time-boxed rules switch themselves off — nothing keeps '
          'forwarding after the work is done.',
          style: textTheme.bodyMedium?.copyWith(color: t.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final duration in _CaDuration.values) ...[
          _DurationOption(
            icon: duration.icon,
            label: duration.label,
            sublabel: sublabel(duration),
            selected: _duration == duration,
            onTap: () => setState(() => _duration = duration),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  // ── Step 4: confirm ───────────────────────────────────────────────────

  Widget _buildConfirmStep(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final recipient = _selectedRecipient;
    final expiry = _duration.expiryFrom(DateTime.now());
    final dateFormat = DateFormat('d MMM');
    final untilValue = expiry == null
        ? _duration.label
        : '${_duration.label} · until ${dateFormat.format(expiry)}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        AppSpacing.xxl,
      ),
      children: [
        Text('Review and confirm', style: textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'One rule, named “Financial → CA”, that you can edit or turn '
          'off anytime.',
          style: textTheme.bodyMedium?.copyWith(color: t.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (recipient != null)
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: t.primarySubtle,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        recipient.initials,
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
                            recipient.name,
                            style: textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            recipient.phone,
                            style: textTheme.bodySmall
                                ?.copyWith(color: t.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.sm),
              Divider(height: 1, color: t.border),
              const SizedBox(height: AppSpacing.sm),
              _SummaryRow(
                icon: Icons.category_outlined,
                label: 'What',
                value: _includeBankingLogin
                    ? 'Bank transactions, UPI, cards, tax, investments '
                        '& banking logins'
                    : 'Bank transactions, UPI, cards, tax & investments',
              ),
              const SizedBox(height: AppSpacing.sm),
              _SummaryRow(
                icon: Icons.schedule_rounded,
                label: 'Duration',
                value: untilValue,
              ),
              const SizedBox(height: AppSpacing.sm),
              _SummaryRow(
                icon: _requireApproval
                    ? Icons.how_to_reg_outlined
                    : Icons.forward_to_inbox_outlined,
                label: 'Delivery',
                value: _requireApproval
                    ? 'Each message asks for your approval first'
                    : 'Messages forward automatically',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                SwitchListTile(
                  value: _requireApproval,
                  onChanged: (value) =>
                      setState(() => _requireApproval = value),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xxs,
                  ),
                  title: const Text('Ask before each forward'),
                  subtitle: Text(
                    'Recommended for money OTPs — you approve every '
                    'message before it leaves your phone.',
                    style: textTheme.bodySmall
                        ?.copyWith(color: t.textSecondary),
                  ),
                ),
                if (!_requireApproval)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: t.warningSubtle,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 18, color: t.warning),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              'Messages will be forwarded automatically — '
                              'including bank OTPs.',
                              style: textTheme.bodySmall
                                  ?.copyWith(color: t.warning),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Divider(
                  height: 1,
                  indent: AppSpacing.md,
                  endIndent: AppSpacing.md,
                  color: t.border,
                ),
                SwitchListTile(
                  value: _includeBankingLogin,
                  onChanged: (value) =>
                      setState(() => _includeBankingLogin = value),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xxs,
                  ),
                  title: const Text('Include banking login codes'),
                  subtitle: Text(
                    'Net-banking and bank-app login OTPs. Off by default.',
                    style: textTheme.bodySmall
                        ?.copyWith(color: t.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'You can pause, edit or delete this rule anytime from the Rules '
          'tab.',
          style: textTheme.bodySmall?.copyWith(color: t.textTertiary),
        ),
      ],
    );
  }
}

/// Animated progress dots for the four steps.
class _StepDots extends StatelessWidget {
  const _StepDots({required this.step, required this.count});

  final int step;
  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: AppMotion.base,
            curve: AppMotion.enter,
            width: i == step ? 24 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
            decoration: BoxDecoration(
              color: i <= step ? t.primary : t.border,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
      ],
    );
  }
}

/// Single-select recipient row with an initials avatar.
class _RecipientOption extends StatelessWidget {
  const _RecipientOption({
    required this.recipient,
    required this.selected,
    required this.onTap,
  });

  final Recipient recipient;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return GlassCard(
      onTap: onTap,
      borderColor: selected ? t.primary : null,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.primarySubtle,
              shape: BoxShape.circle,
            ),
            child: Text(
              recipient.initials,
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
                  recipient.name,
                  style: textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  recipient.phone,
                  style:
                      textTheme.bodySmall?.copyWith(color: t.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(
            selected
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 22,
            color: selected ? t.primary : t.textTertiary,
          ),
        ],
      ),
    );
  }
}

/// Big preset chip for the duration step.
class _DurationOption extends StatelessWidget {
  const _DurationOption({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return GlassCard(
      onTap: onTap,
      borderColor: selected ? t.primary : null,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? t.primarySubtle : t.surfaceSunken,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              icon,
              size: 22,
              color: selected ? t.onPrimarySubtle : t.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  sublabel,
                  style:
                      textTheme.bodySmall?.copyWith(color: t.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(
            selected
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 22,
            color: selected ? t.primary : t.textTertiary,
          ),
        ],
      ),
    );
  }
}

/// Icon + label + value line inside the confirmation summary card.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: t.textTertiary),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: textTheme.bodySmall?.copyWith(color: t.textTertiary),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(value, style: textTheme.bodyMedium),
        ),
      ],
    );
  }
}
