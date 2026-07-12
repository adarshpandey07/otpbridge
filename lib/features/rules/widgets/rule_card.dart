import 'package:flutter/material.dart';

import 'package:otpbridge/core/theme/app_colors.dart';
import 'package:otpbridge/core/theme/app_spacing.dart';
import 'package:otpbridge/core/widgets/widgets.dart';
import 'package:otpbridge/domain/models/models.dart';

import 'rule_summary.dart';

/// A single rule in the reorderable rules list: drag handle, name,
/// human-readable condition summary, action badge and enable switch.
class RuleCard extends StatelessWidget {
  const RuleCard({
    super.key,
    required this.rule,
    required this.index,
    required this.recipientsById,
    required this.onTap,
    required this.onToggle,
  });

  final ForwardRule rule;

  /// Position in the list, used by the drag handle to start a reorder.
  final int index;

  final Map<String, Recipient> recipientsById;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    final (actionLabel, actionTone) = switch (rule.action) {
      RuleAction.forward => ('Forward', PillTone.success),
      RuleAction.requireApproval => ('Ask first', PillTone.warning),
      RuleAction.block => ('Block', PillTone.danger),
    };

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Container(
              width: AppSpacing.touchTarget,
              height: AppSpacing.touchTarget,
              color: Colors.transparent,
              alignment: Alignment.center,
              child: Icon(
                Icons.drag_indicator_rounded,
                size: 20,
                color: t.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: AnimatedOpacity(
              duration: AppMotion.base,
              curve: AppMotion.enter,
              opacity: rule.enabled ? 1 : 0.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          rule.name,
                          style: textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      StatusPill(
                        label: actionLabel,
                        tone: actionTone,
                        dense: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    ruleSummary(context, rule, recipientsById),
                    style: textTheme.bodySmall
                        ?.copyWith(color: t.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Switch(value: rule.enabled, onChanged: onToggle),
        ],
      ),
    );
  }
}
