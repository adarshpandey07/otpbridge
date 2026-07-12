import 'package:flutter/material.dart';

import 'package:otpbridge/core/theme/app_colors.dart';
import 'package:otpbridge/core/theme/app_spacing.dart';
import 'package:otpbridge/core/widgets/widgets.dart';

/// A compact dashboard stat: small tinted icon, big tabular number, label.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.tone = PillTone.neutral,
  });

  final int value;
  final String label;
  final IconData icon;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (bg, fg) = switch (tone) {
      PillTone.neutral => (t.surfaceSunken, t.textSecondary),
      PillTone.primary => (t.primarySubtle, t.onPrimarySubtle),
      PillTone.success => (t.successSubtle, t.success),
      PillTone.warning => (t.warningSubtle, t.warning),
      PillTone.danger => (t.dangerSubtle, t.danger),
      PillTone.info => (t.infoSubtle, t.info),
    };

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, size: 15, color: fg),
          ),
          const Spacer(),
          Text(
            '$value',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: t.textSecondary),
          ),
        ],
      ),
    );
  }
}
