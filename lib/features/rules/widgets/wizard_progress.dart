import 'package:flutter/material.dart';

import 'package:otpbridge/core/theme/app_colors.dart';
import 'package:otpbridge/core/theme/app_spacing.dart';

/// Segmented progress bar shown at the top of the new-rule wizard.
/// One rounded segment per step; completed and current segments fill in.
class WizardProgress extends StatelessWidget {
  const WizardProgress({
    super.key,
    required this.current,
    required this.total,
  });

  /// Zero-based index of the active step.
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: AnimatedContainer(
              duration: AppMotion.base,
              curve: AppMotion.enter,
              height: 4,
              decoration: BoxDecoration(
                color: i <= current ? t.primary : t.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
