import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:otpbridge/app/providers.dart';
import 'package:otpbridge/app/router.dart';
import 'package:otpbridge/core/theme/app_colors.dart';
import 'package:otpbridge/core/theme/app_spacing.dart';
import 'package:otpbridge/core/widgets/widgets.dart';
import 'package:otpbridge/domain/models/models.dart';
import 'package:otpbridge/features/assistant/assistant_screen.dart';

import 'widgets/rule_card.dart';

/// The forwarding rules list: reorderable, with per-rule enable switches.
/// Rules are evaluated top to bottom — the first match wins.
class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  void _reorder(
    WidgetRef ref,
    List<ForwardRule> rules,
    int oldIndex,
    int newIndex,
  ) {
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;
    final updated = [...rules];
    final moved = updated.removeAt(oldIndex);
    updated.insert(newIndex, moved);
    ref.read(rulesRepositoryProvider).saveAll([
      for (var i = 0; i < updated.length; i++)
        updated[i].copyWith(sortOrder: i),
    ]);
  }

  /// Opens the natural-language rule assistant (or the paywall when the
  /// free-tier rule cap is reached — the assistant creates rules too).
  void _openAssistant(BuildContext context, {required bool atCap}) {
    if (atCap) {
      context.push(Routes.paywall);
      return;
    }
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const AssistantScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    final rulesAsync = ref.watch(rulesProvider);
    final rules = rulesAsync.valueOrNull ?? const <ForwardRule>[];
    final recipients =
        ref.watch(recipientsProvider).valueOrNull ?? const <Recipient>[];
    final recipientsById = {for (final r in recipients) r.id: r};
    final subscription = ref.watch(subscriptionProvider).valueOrNull;
    final limits = subscription?.limits ?? TierLimits.free;
    final atCap = subscription != null &&
        subscription.tier == SubscriptionTier.free &&
        limits.maxRules >= 0 &&
        rules.length >= limits.maxRules;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.lg,
                AppSpacing.screenH,
                AppSpacing.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Forwarding rules',
                            style: textTheme.headlineLarge),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          'Evaluated top to bottom — first match wins.',
                          style: textTheme.bodySmall
                              ?.copyWith(color: t.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _HeaderButton(
                    icon: Icons.auto_awesome_outlined,
                    tooltip: atCap
                        ? 'Free plan limit reached — upgrade for '
                            'unlimited rules'
                        : 'Describe a rule',
                    onPressed: () => _openAssistant(context, atCap: atCap),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _HeaderButton(
                    icon: atCap
                        ? Icons.lock_outline_rounded
                        : Icons.add_rounded,
                    tooltip: atCap
                        ? 'Free plan limit reached — upgrade for '
                            'unlimited rules'
                        : 'New rule',
                    onPressed: () => context
                        .push(atCap ? Routes.paywall : Routes.ruleEditor),
                  ),
                ],
              ),
            ),
            Expanded(
              child: rulesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) => EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Couldn’t load rules',
                  message: '$error',
                ),
                data: (rules) {
                  if (rules.isEmpty) {
                    return EmptyState(
                      icon: Icons.alt_route_rounded,
                      title: 'No rules yet',
                      message:
                          'Rules decide which OTPs get forwarded, to whom, '
                          'and when.',
                      action: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FilledButton.icon(
                            onPressed: () => context.push(Routes.ruleEditor),
                            style: FilledButton.styleFrom(
                              minimumSize:
                                  const Size(0, AppSpacing.touchTarget),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xl),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 20),
                            label: const Text('Create your first rule'),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          TextButton.icon(
                            onPressed: () =>
                                _openAssistant(context, atCap: false),
                            style: TextButton.styleFrom(
                              minimumSize:
                                  const Size(0, AppSpacing.touchTarget),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xl),
                            ),
                            icon: const Icon(Icons.auto_awesome_outlined,
                                size: 18),
                            label: const Text('Or describe it in a sentence'),
                          ),
                        ],
                      ),
                    );
                  }
                  return ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH,
                      0,
                      AppSpacing.screenH,
                      AppSpacing.xxl,
                    ),
                    itemCount: rules.length,
                    onReorder: (oldIndex, newIndex) =>
                        _reorder(ref, rules, oldIndex, newIndex),
                    proxyDecorator: (child, _, animation) => AnimatedBuilder(
                      animation: animation,
                      builder: (context, _) => Transform.scale(
                        scale: 1 +
                            0.02 *
                                AppMotion.enter.transform(animation.value),
                        child: child,
                      ),
                    ),
                    itemBuilder: (context, index) {
                      final rule = rules[index];
                      return Padding(
                        key: ValueKey(rule.id),
                        padding:
                            const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: RuleCard(
                          rule: rule,
                          index: index,
                          recipientsById: recipientsById,
                          onTap: () =>
                              context.push(Routes.ruleEditor, extra: rule),
                          onToggle: (enabled) => ref
                              .read(rulesRepositoryProvider)
                              .save(rule.copyWith(enabled: enabled)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Square header action button ("describe a rule" / "+"). At the free-tier
/// rule cap both actions show a lock tooltip and route to the paywall.
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: AppSpacing.touchTarget,
        height: AppSpacing.touchTarget,
        child: IconButton(
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: t.primarySubtle,
            foregroundColor: t.onPrimarySubtle,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          icon: Icon(icon),
        ),
      ),
    );
  }
}
