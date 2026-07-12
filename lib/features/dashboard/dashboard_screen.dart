import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:otpbridge/app/providers.dart';
import 'package:otpbridge/app/router.dart';
import 'package:otpbridge/core/theme/app_colors.dart';
import 'package:otpbridge/core/theme/app_spacing.dart';
import 'package:otpbridge/core/theme/app_theme.dart';
import 'package:otpbridge/core/widgets/widgets.dart';
import 'package:otpbridge/data/suggestions/suggestion_engine.dart';
import 'package:otpbridge/domain/models/models.dart';
import 'package:otpbridge/features/approvals/approval_sheet.dart';
import 'package:otpbridge/features/ca_flow/ca_forwarding_screen.dart';
import 'package:otpbridge/features/dashboard/widgets/activity_row.dart';
import 'package:otpbridge/features/dashboard/widgets/stat_tile.dart';
import 'package:otpbridge/features/history/widgets/history_detail_sheet.dart';

/// Home tab: greeting, listening state, today's numbers, approvals that need
/// attention, one AI suggestion, plan usage and the latest activity.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static String _greeting(DateTime now) {
    if (now.hour < 12) return 'Good morning';
    if (now.hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static bool _isToday(DateTime time, DateTime now) =>
      time.year == now.year && time.month == now.month && time.day == now.day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final now = DateTime.now();

    final settings = ref.watch(settingsProvider).valueOrNull;
    final historyAsync = ref.watch(historyProvider);
    final approvals = ref.watch(approvalsProvider).valueOrNull ?? const [];
    final queue = ref.watch(queueProvider).valueOrNull ?? const [];
    final suggestions = ref.watch(suggestionsProvider).valueOrNull ?? const [];
    final smartSuggestions =
        ref.watch(smartSuggestionsProvider).valueOrNull ?? const [];
    final subscription = ref.watch(subscriptionProvider).valueOrNull;

    final pendingApprovals =
        approvals.where((a) => !a.isExpired(now)).toList();
    final suggestion =
        suggestions.where((s) => !s.dismissed).cast<AiSuggestion?>().firstWhere(
              (_) => true,
              orElse: () => null,
            );
    final queuedCount = queue.where((task) => !task.isTerminal).length;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.xl,
            AppSpacing.screenH,
            AppSpacing.xl,
          ),
          children: [
            Text(_greeting(now),
                style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Your OTPs, forwarded on your terms',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: t.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (settings != null) ...[
              _ListeningCard(listening: settings.listeningEnabled),
              const SizedBox(height: AppSpacing.xl),
            ],
            SectionHeader(
              title: 'Today',
              subtitle: 'What OTPBridge handled since midnight',
            ),
            historyAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => GlassCard(
                child: Text(
                  'Stats unavailable: $error',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: t.danger),
                ),
              ),
              data: (entries) {
                final today =
                    entries.where((e) => _isToday(e.at, now)).toList();
                int count(Set<OtpOutcome> outcomes) =>
                    today.where((e) => outcomes.contains(e.outcome)).length;
                return GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                    mainAxisExtent: 112,
                  ),
                  children: [
                    StatTile(
                      value: count(
                          {OtpOutcome.forwarded, OtpOutcome.approved}),
                      label: 'Forwarded',
                      icon: Icons.send_rounded,
                      tone: PillTone.success,
                    ),
                    StatTile(
                      value:
                          count({OtpOutcome.blocked, OtpOutcome.rejected}),
                      label: 'Blocked',
                      icon: Icons.block_rounded,
                      tone: PillTone.danger,
                    ),
                    StatTile(
                      value: pendingApprovals.length,
                      label: 'Pending approval',
                      icon: Icons.hourglass_top_rounded,
                      tone: PillTone.warning,
                    ),
                    StatTile(
                      value: queuedCount,
                      label: 'Queued',
                      icon: Icons.schedule_rounded,
                      tone: PillTone.info,
                    ),
                  ],
                );
              },
            ),
            if (pendingApprovals.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              SectionHeader(
                title: 'Needs your approval',
                subtitle: 'High-risk OTPs held until you decide',
                trailing: StatusPill(
                  label: '${pendingApprovals.length}',
                  tone: PillTone.warning,
                  dense: true,
                ),
              ),
              for (final approval in pendingApprovals) ...[
                _ApprovalCard(approval: approval),
                const SizedBox(height: AppSpacing.xs),
              ],
            ],
            if (smartSuggestions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              SectionHeader(
                title: 'Suggested for you',
                subtitle: 'From services that message this device',
              ),
              for (final s in smartSuggestions.take(3)) ...[
                _SmartSuggestionCard(suggestion: s),
                const SizedBox(height: AppSpacing.xs),
              ],
            ] else if (suggestion != null) ...[
              const SizedBox(height: AppSpacing.xl),
              _SuggestionCard(suggestion: suggestion),
            ],
            const SizedBox(height: AppSpacing.xl),
            _CaQuickCard(onTap: () => openCaFlow(context)),
            if (subscription != null &&
                subscription.tier == SubscriptionTier.free) ...[
              const SizedBox(height: AppSpacing.xl),
              _SubscriptionStrip(subscription: subscription),
            ],
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(
              title: 'Recent activity',
              trailing: TextButton(
                onPressed: () => context.go(Routes.history),
                child: const Text('View all'),
              ),
            ),
            historyAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (entries) {
                final recent = [...entries]
                  ..sort((a, b) => b.at.compareTo(a.at));
                final latest = recent.take(5).toList();
                if (latest.isEmpty) {
                  return const GlassCard(
                    child: EmptyState(
                      icon: Icons.inbox_outlined,
                      title: 'No activity yet',
                      message: 'OTPs you receive will appear here once '
                          'forwarding starts.',
                    ),
                  );
                }
                return GlassCard(
                  padding: const EdgeInsets.all(AppSpacing.xxs),
                  child: Column(
                    children: [
                      for (var i = 0; i < latest.length; i++) ...[
                        ActivityRow(
                          key: ValueKey(latest[i].id),
                          entry: latest[i],
                          onTap: () =>
                              showHistoryDetail(context, latest[i]),
                        ),
                        if (i < latest.length - 1)
                          const Divider(indent: 68, endIndent: 12),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Read-only listening state; the toggle itself lives in Settings.
class _ListeningCard extends StatelessWidget {
  const _ListeningCard({required this.listening});

  final bool listening;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = listening ? t.success : t.warning;
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listening ? 'Listening for OTPs' : 'Listening paused',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  listening
                      ? 'New messages are screened on-device.'
                      : 'Resume listening from Settings.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: t.textTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          StatusPill(
            label: listening ? 'Active' : 'Paused',
            tone: listening ? PillTone.success : PillTone.warning,
            dense: true,
          ),
        ],
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({required this.approval});

  final PendingApproval approval;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = approval.classification;
    final title = (c.brand != null && c.brand!.isNotEmpty)
        ? c.brand!
        : c.category.label;

    return GlassCard(
      borderColor: t.warning.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryAvatar(category: c.category, size: 44),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c.category.label,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: t.textTertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              if (c.hasOtp)
                Text(
                  ActivityRow.maskOtp(c.otp!),
                  style: MonoText.otp(context, size: 14)
                      .copyWith(color: t.textSecondary),
                ),
            ],
          ),
          if (approval.reason != null && approval.reason!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              approval.reason!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: t.textSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _ApprovalCountdown(expiresAt: approval.expiresAt),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () => showApprovalSheet(context, approval),
                child: const Text('Review'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ticks once a second toward [expiresAt].
class _ApprovalCountdown extends StatefulWidget {
  const _ApprovalCountdown({required this.expiresAt});

  final DateTime expiresAt;

  @override
  State<_ApprovalCountdown> createState() => _ApprovalCountdownState();
}

class _ApprovalCountdownState extends State<_ApprovalCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.expiresAt.difference(DateTime.now());
    if (remaining.isNegative) {
      return const StatusPill(
        label: 'Expired',
        tone: PillTone.neutral,
        icon: Icons.timer_off_outlined,
        dense: true,
      );
    }
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    final label =
        'Expires in $minutes:${seconds.toString().padLeft(2, '0')}';
    return StatusPill(
      label: label,
      tone: remaining.inSeconds < 60 ? PillTone.danger : PillTone.warning,
      icon: Icons.timer_outlined,
      dense: true,
    );
  }
}

class _SuggestionCard extends ConsumerWidget {
  const _SuggestionCard({required this.suggestion});

  final AiSuggestion suggestion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: t.primarySubtle,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 20,
                  color: t.onPrimarySubtle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      suggestion.body,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: t.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => ref
                    .read(suggestionsRepositoryProvider)
                    .save(suggestion.copyWith(dismissed: true)),
                child: const Text('Dismiss'),
              ),
              const SizedBox(width: AppSpacing.xs),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () => context.push(
                  Routes.ruleEditor,
                  extra: suggestion.proposedRule,
                ),
                child: const Text('Create automation'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A proactively-detected automation suggestion (derived from the SMS inbox).
class _SmartSuggestionCard extends ConsumerWidget {
  const _SmartSuggestionCard({required this.suggestion});

  final AiSuggestion suggestion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final category = suggestion.proposedRule.categories.isNotEmpty
        ? suggestion.proposedRule.categories.first
        : OtpCategory.unknown;
    return GlassCard(
      onTap: () =>
          context.push(Routes.ruleEditor, extra: suggestion.proposedRule),
      child: Row(
        children: [
          CategoryAvatar(category: category, size: 40),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(suggestion.title,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  suggestion.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: t.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(Icons.add_circle_outline_rounded, color: t.primary),
        ],
      ),
    );
  }
}

/// One-tap entry to the CA/accountant financial-forwarding flow.
class _CaQuickCard extends StatelessWidget {
  const _CaQuickCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: t.infoSubtle,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.account_balance_wallet_outlined,
                size: 20, color: t.info),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Forward finances to your CA',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  'Bank, tax & investment messages — set it up in seconds',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: t.textSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: t.textTertiary),
        ],
      ),
    );
  }
}

/// Free-plan usage: forwards used this month with a slim progress bar.
class _SubscriptionStrip extends StatelessWidget {
  const _SubscriptionStrip({required this.subscription});

  final SubscriptionState subscription;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final limit = subscription.limits.monthlyForwards;
    final used = subscription.forwardsUsed.clamp(0, limit);
    final fraction = limit == 0 ? 0.0 : used / limit;
    final barColor = subscription.forwardsRemaining == 0
        ? t.danger
        : fraction >= 0.8
            ? t.warning
            : t.primary;

    return GlassCard(
      onTap: () => context.push(Routes.paywall),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Free plan',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                '$used of $limit forwards used',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: t.textSecondary),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: t.textTertiary),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 6,
              color: barColor,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subscription.forwardsRemaining == 0
                ? 'Limit reached — upgrade for unlimited forwards'
                : '${subscription.forwardsRemaining} left this month · '
                    'Upgrade for unlimited',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: t.textTertiary),
          ),
        ],
      ),
    );
  }
}
