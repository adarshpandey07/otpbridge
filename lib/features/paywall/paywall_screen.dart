import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:otpbridge/app/providers.dart';
import 'package:otpbridge/core/theme/app_colors.dart';
import 'package:otpbridge/core/theme/app_spacing.dart';
import 'package:otpbridge/core/theme/app_theme.dart';
import 'package:otpbridge/core/widgets/widgets.dart';
import 'package:otpbridge/domain/models/models.dart';
import 'package:otpbridge/domain/services/billing_service.dart';

/// The upgrade screen: a calm Free vs Premium comparison driven by
/// [TierLimits], a Monthly/Yearly plan toggle, and a real checkout through
/// [BillingService] (Razorpay when a key is configured; demo mode otherwise).
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  PremiumPlan _plan = PremiumPlan.monthly;
  bool _busy = false;
  bool _justUpgraded = false;

  static String _limitLabel(int value) => value < 0 ? 'Unlimited' : '$value';

  /// "Save ~16%" — derived from the real plan prices so it never lies.
  static int get _yearlySavePercent =>
      100 -
      (PremiumPlan.yearly.priceInPaise *
              100 /
              (PremiumPlan.monthly.priceInPaise * 12))
          .round();

  static String get _yearlyPerMonth =>
      '₹${(PremiumPlan.yearly.priceInPaise / 100 / 12).round()}';

  // ── Checkout ─────────────────────────────────────────────────────────────

  Future<void> _checkout() async {
    if (_busy || _justUpgraded) return;
    setState(() => _busy = true);

    final plan = _plan;
    try {
      // Prefill checkout with the default recipient's details when available —
      // never make the user type what the app already knows.
      final settings = ref.read(settingsProvider).valueOrNull;
      final recipients =
          ref.read(recipientsProvider).valueOrNull ?? const <Recipient>[];
      Recipient? contact;
      for (final r in recipients) {
        if (r.id == settings?.defaultRecipientId) contact = r;
      }
      contact ??= recipients.isNotEmpty ? recipients.first : null;
      final name = contact?.name.trim();
      final phone = contact?.phone.trim();

      final result = await ref.read(billingServiceProvider).checkout(
            plan: plan,
            userName: (name == null || name.isEmpty) ? 'OTPBridge User' : name,
            email: contact?.email,
            phone: (phone == null || phone.isEmpty) ? null : phone,
          );
      if (!mounted) return;

      switch (result.status) {
        case BillingStatus.success:
          await _activatePremium(plan);
        case BillingStatus.cancelled:
          // User backed out — quiet dismiss, no scary error.
          setState(() => _busy = false);
        case BillingStatus.failed:
          setState(() => _busy = false);
          _showFailed(result.message);
        case BillingStatus.unsupported:
          setState(() => _busy = false);
          _showSnack(
            'Payments are not available on this device yet.',
            icon: Icons.info_outline_rounded,
          );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showFailed(null);
    }
  }

  Future<void> _activatePremium(PremiumPlan plan) async {
    // TODO: server-side signature verification via /functions/v1/verify-purchase
    // before granting premium in production (see docs/BACKEND.md).
    // Flip to the success state first so the premium "manage" view doesn't
    // flash in when the subscription stream emits.
    setState(() {
      _busy = false;
      _justUpgraded = true;
    });
    final repo = ref.read(subscriptionRepositoryProvider);
    final current = await repo.get();
    await repo.save(current.copyWith(
      tier: SubscriptionTier.premium,
      expiresAt: DateTime.now().add(Duration(days: plan.durationDays)),
    ));

    // Let the success state land before dismissing.
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    _showSnack(
      'Welcome to Premium — everything is unlocked.',
      icon: Icons.workspace_premium_rounded,
    );
    context.pop();
  }

  void _showFailed(String? detail) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          detail == null || detail.isEmpty
              ? 'Payment did not go through — you have not been charged.'
              : 'Payment did not go through — you have not been charged. '
                  '($detail)',
        ),
        action: SnackBarAction(label: 'Retry', onPressed: _checkout),
      ),
    );
  }

  void _showSnack(String message, {IconData? icon}) {
    final t = context.tokens;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: icon == null
            ? Text(message)
            : Row(
                children: [
                  // Snackbar surface is t.textPrimary; content color is
                  // t.surface (see app_theme snackBarTheme).
                  Icon(icon, size: 18, color: t.surface),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(child: Text(message)),
                ],
              ),
      ),
    );
  }

  // ── Restore / manage ─────────────────────────────────────────────────────

  Future<void> _restore() async {
    if (_busy) return;
    // Local check only until a backend exists: re-read the stored
    // subscription and report what this device knows.
    final current = await ref.read(subscriptionRepositoryProvider).get();
    if (!mounted) return;
    final active = current.tier == SubscriptionTier.premium &&
        (current.expiresAt == null ||
            current.expiresAt!.isAfter(DateTime.now()));
    _showSnack(
      active
          ? 'Premium is active on this device.'
          : 'No previous purchase found on this device.',
      icon: active ? Icons.check_circle_outline_rounded : null,
    );
  }

  Future<void> _downgradeToFree() async {
    final repo = ref.read(subscriptionRepositoryProvider);
    final current = await repo.get();
    // Built directly (not copyWith) so expiresAt is cleared.
    await repo.save(SubscriptionState(
      tier: SubscriptionTier.free,
      forwardsUsed: current.forwardsUsed,
      periodStart: current.periodStart,
    ));
    if (!mounted) return;
    _showSnack('Switched to the Free plan.');
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sub = ref.watch(subscriptionProvider).valueOrNull;
    final isPremium = sub?.tier == SubscriptionTier.premium;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: SafeArea(
        child: isPremium && !_justUpgraded
            ? _PremiumActiveView(
                subscription: sub!,
                onDone: () => context.pop(),
                onDowngrade: _downgradeToFree,
              )
            : _buildUpgradeView(context),
      ),
    );
  }

  Widget _buildUpgradeView(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final isConfigured = ref.watch(billingServiceProvider).isConfigured;
    const free = TierLimits.free;
    const premium = TierLimits.premium;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.xs,
        AppSpacing.screenH,
        AppSpacing.xl,
      ),
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: t.primarySubtle,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(
              Icons.workspace_premium_outlined,
              size: 32,
              color: t.onPrimarySubtle,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'OTPBridge Premium',
          textAlign: TextAlign.center,
          style: textTheme.displaySmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Unlimited forwarding, smarter rules and full control — on the '
          'same private, on-device engine.',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: t.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        GlassCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Column(
            children: [
              const _CompareHeader(),
              const Divider(height: 1),
              _CompareRow(
                label: 'Monthly forwards',
                free: _limitLabel(free.monthlyForwards),
                premium: _limitLabel(premium.monthlyForwards),
              ),
              const Divider(height: 1),
              _CompareRow(
                label: 'Forwarding rules',
                free: _limitLabel(free.maxRules),
                premium: _limitLabel(premium.maxRules),
              ),
              const Divider(height: 1),
              _CompareRow(
                label: 'Recipients',
                free: _limitLabel(free.maxRecipients),
                premium: _limitLabel(premium.maxRecipients),
              ),
              const Divider(height: 1),
              _CompareRow(
                label: 'Advanced schedules',
                free: free.advancedSchedules ? 'Yes' : null,
                premium: premium.advancedSchedules ? null : 'No',
              ),
              const Divider(height: 1),
              _CompareRow(
                label: 'Banking cap customization',
                free: free.canCustomizeBankingCap ? 'Yes' : null,
                premium: premium.canCustomizeBankingCap ? null : 'No',
              ),
              const Divider(height: 1),
              const _CompareRow(label: 'Advanced AI classification'),
              const Divider(height: 1),
              const _CompareRow(label: 'Forwarding analytics'),
              const Divider(height: 1),
              const _CompareRow(label: 'Priority sync'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _PlanCard(
                  title: 'Monthly',
                  plan: PremiumPlan.monthly,
                  caption: 'Billed monthly',
                  selected: _plan == PremiumPlan.monthly,
                  enabled: !_busy && !_justUpgraded,
                  onTap: () => setState(() => _plan = PremiumPlan.monthly),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _PlanCard(
                  title: 'Yearly',
                  plan: PremiumPlan.yearly,
                  badge: 'Save ~$_yearlySavePercent%',
                  caption: '≈ $_yearlyPerMonth/month',
                  selected: _plan == PremiumPlan.yearly,
                  enabled: !_busy && !_justUpgraded,
                  onTap: () => setState(() => _plan = PremiumPlan.yearly),
                ),
              ),
            ],
          ),
        ),
        if (!isConfigured) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: t.infoSubtle,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: t.info),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Demo mode — no real charge. Add a payment gateway key '
                    'for live payments.',
                    style:
                        textTheme.bodySmall?.copyWith(color: t.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        AnimatedSwitcher(
          duration: AppMotion.base,
          switchInCurve: AppMotion.enter,
          switchOutCurve: AppMotion.exit,
          child: _justUpgraded
              ? Container(
                  key: const ValueKey('upgraded'),
                  height: 52,
                  decoration: BoxDecoration(
                    color: t.successSubtle,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, color: t.success),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Welcome to Premium',
                        style: textTheme.titleSmall?.copyWith(
                          color: t.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              : FilledButton(
                  key: const ValueKey('upgrade'),
                  onPressed: _busy ? null : _checkout,
                  child: _busy
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: t.onPrimary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            const Text('Opening checkout…'),
                          ],
                        )
                      : Text(
                          'Upgrade — ${_plan.displayPrice}/${_plan.periodLabel}',
                        ),
                ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'One-time payment for the period. Cancel anytime — no auto-renew.',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: t.textTertiary),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: _busy ? null : _restore,
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSpacing.touchTarget),
          ),
          child: const Text('Restore purchase'),
        ),
        TextButton(
          onPressed: () => context.pop(),
          style: TextButton.styleFrom(
            foregroundColor: t.textSecondary,
            minimumSize: const Size.fromHeight(AppSpacing.touchTarget),
          ),
          child: const Text('Maybe later'),
        ),
      ],
    );
  }
}

// ── Plan toggle ──────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.plan,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.badge,
    this.caption,
  });

  final String title;
  final PremiumPlan plan;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final String? badge;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      selected: selected,
      button: true,
      label: '$title plan, ${plan.displayPrice} per ${plan.periodLabel}',
      child: GlassCard(
        onTap: enabled ? onTap : null,
        borderColor: selected ? t.primary : null,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: selected ? t.primary : t.textTertiary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    title,
                    style: textTheme.labelLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (badge != null)
                  StatusPill(label: badge!, tone: PillTone.success, dense: true),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  plan.displayPrice,
                  style: MonoText.amount(context, size: 22)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                Flexible(
                  child: Text(
                    ' /${plan.periodLabel}',
                    style:
                        textTheme.bodySmall?.copyWith(color: t.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (caption != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                caption!,
                style: textTheme.bodySmall?.copyWith(color: t.textTertiary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Already-premium state ────────────────────────────────────────────────────

class _PremiumActiveView extends StatelessWidget {
  const _PremiumActiveView({
    required this.subscription,
    required this.onDone,
    required this.onDowngrade,
  });

  final SubscriptionState subscription;
  final VoidCallback onDone;
  final Future<void> Function() onDowngrade;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final expiry = subscription.expiresAt;
    final expiryLabel = expiry == null
        ? 'No expiry set'
        : DateFormat('d MMM yyyy').format(expiry);
    final expired = expiry != null && expiry.isBefore(DateTime.now());

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.xs,
        AppSpacing.screenH,
        AppSpacing.xl,
      ),
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: t.successSubtle,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(
              Icons.workspace_premium_rounded,
              size: 32,
              color: t.success,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          "You're on Premium",
          textAlign: TextAlign.center,
          style: textTheme.displaySmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Unlimited forwards, rules and recipients are unlocked on this '
          'device.',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: t.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        GlassCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: Text('Plan', style: textTheme.bodyMedium)),
                  StatusPill(
                    label: expired ? 'Expired' : 'Active',
                    tone: expired ? PillTone.warning : PillTone.success,
                    icon: expired
                        ? Icons.schedule_rounded
                        : Icons.check_rounded,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      expired ? 'Expired on' : 'Premium until',
                      style: textTheme.bodyMedium,
                    ),
                  ),
                  Text(expiryLabel, style: MonoText.amount(context)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Forwards this month',
                      style: textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    '${subscription.forwardsUsed} · Unlimited',
                    style: MonoText.amount(context),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(onPressed: onDone, child: const Text('Done')),
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          onPressed: () => onDowngrade(),
          style: TextButton.styleFrom(
            foregroundColor: t.textSecondary,
            minimumSize: const Size.fromHeight(AppSpacing.touchTarget),
          ),
          child: const Text('Downgrade to Free (dev)'),
        ),
      ],
    );
  }
}

// ── Comparison table ─────────────────────────────────────────────────────────

const double _freeColumnWidth = 64;
const double _premiumColumnWidth = 88;

class _CompareHeader extends StatelessWidget {
  const _CompareHeader();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          const Spacer(),
          SizedBox(
            width: _freeColumnWidth,
            child: Text(
              'Free',
              textAlign: TextAlign.center,
              style: textTheme.labelMedium,
            ),
          ),
          SizedBox(
            width: _premiumColumnWidth,
            child: Text(
              'Premium',
              textAlign: TextAlign.center,
              style: textTheme.labelMedium?.copyWith(
                color: t.onPrimarySubtle,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One comparison row. A null value renders as "not included" (an em dash)
/// in the Free column and as an included check in the Premium column.
class _CompareRow extends StatelessWidget {
  const _CompareRow({required this.label, this.free, this.premium});

  final String label;
  final String? free;
  final String? premium;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(label, style: textTheme.bodyMedium)),
          SizedBox(
            width: _freeColumnWidth,
            child: free == null
                ? Text(
                    '—',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium
                        ?.copyWith(color: t.textTertiary),
                  )
                : Text(
                    free!,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium
                        ?.copyWith(color: t.textSecondary),
                  ),
          ),
          SizedBox(
            width: _premiumColumnWidth,
            child: premium == null
                ? Icon(Icons.check_rounded, size: 18, color: t.success)
                : Text(
                    premium!,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
    );
  }
}
