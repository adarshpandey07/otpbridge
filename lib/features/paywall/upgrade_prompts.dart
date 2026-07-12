import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:otpbridge/app/router.dart';
import 'package:otpbridge/core/theme/app_colors.dart';
import 'package:otpbridge/core/theme/app_spacing.dart';

/// Friendly in-flow upgrade prompts, shown when a free user hits a limit.
///
/// Usage from any screen:
/// ```dart
/// await showUpgradeSheet(context,
///     reason: "You've used all 50 free forwards this month.");
/// ```
/// The pipeline already hard-blocks over-limit actions; this is the UX layer
/// that explains the wall and offers the way through.
Future<void> showUpgradeSheet(
  BuildContext context, {
  required String reason,
}) async {
  final t = context.tokens;
  final upgrade = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    backgroundColor: t.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (_) => _UpgradeSheetBody(reason: reason),
  );
  if (upgrade == true && context.mounted) {
    context.push(Routes.paywall);
  }
}

class _UpgradeSheetBody extends StatelessWidget {
  const _UpgradeSheetBody({required this.reason});

  final String reason;

  static const _perks = <(IconData, String)>[
    (Icons.all_inclusive_rounded, 'Unlimited forwards every month'),
    (Icons.rule_rounded, 'Unlimited rules and recipients'),
    (Icons.schedule_rounded, 'Advanced schedules and banking cap control'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: t.borderStrong,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: t.primarySubtle,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(
                  Icons.workspace_premium_outlined,
                  size: 28,
                  color: t.onPrimarySubtle,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              reason,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Premium removes every limit — same private, on-device engine.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: t.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final (icon, label) in _perks)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: t.onPrimarySubtle),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(label, style: textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Upgrade to Premium'),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: t.textSecondary,
                minimumSize: const Size.fromHeight(AppSpacing.touchTarget),
              ),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact inline banner for screens where a free-tier limit is near or
/// reached (e.g. above a disabled "Add rule" button). Tapping "Upgrade"
/// opens the paywall.
class UsageLimitBanner extends StatelessWidget {
  const UsageLimitBanner({
    super.key,
    required this.message,
    this.icon = Icons.lock_outline_rounded,
    this.margin = EdgeInsets.zero,
  });

  final String message;
  final IconData icon;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: margin,
      constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
      padding: const EdgeInsets.only(left: AppSpacing.sm),
      decoration: BoxDecoration(
        color: t.warningSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: t.warning),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodySmall?.copyWith(color: t.textPrimary),
            ),
          ),
          TextButton(
            onPressed: () => context.push(Routes.paywall),
            style: TextButton.styleFrom(
              minimumSize:
                  const Size(AppSpacing.touchTarget, AppSpacing.touchTarget),
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            ),
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }
}
