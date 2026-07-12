import 'package:flutter/material.dart';

import 'package:otpbridge/core/theme/app_colors.dart';
import 'package:otpbridge/core/theme/app_spacing.dart';
import 'package:otpbridge/core/theme/app_theme.dart';
import 'package:otpbridge/core/widgets/widgets.dart';
import 'package:otpbridge/domain/models/models.dart';
import 'package:otpbridge/features/shared/relative_time.dart';

/// Maps an [OtpOutcome] to a [PillTone] so status colors stay consistent
/// across Dashboard, History and the detail sheet.
extension OtpOutcomeTone on OtpOutcome {
  PillTone get tone => switch (this) {
        OtpOutcome.forwarded || OtpOutcome.approved => PillTone.success,
        OtpOutcome.queued => PillTone.info,
        OtpOutcome.pendingApproval => PillTone.warning,
        OtpOutcome.blocked ||
        OtpOutcome.rejected ||
        OtpOutcome.failed =>
          PillTone.danger,
        OtpOutcome.expired || OtpOutcome.ignored => PillTone.neutral,
      };
}

/// One history entry as a compact feed row: category avatar, brand, relative
/// time, outcome pill and a masked OTP. Shared by Dashboard and History.
class ActivityRow extends StatelessWidget {
  const ActivityRow({super.key, required this.entry, this.onTap});

  final HistoryEntry entry;
  final VoidCallback? onTap;

  /// Compact rows show a masked OTP (last two digits visible); the full code
  /// lives in the detail sheet behind the app lock.
  static String maskOtp(String otp) {
    if (otp.length <= 2) return otp;
    return '${'•' * (otp.length - 2)}${otp.substring(otp.length - 2)}';
  }

  String get _title {
    final c = entry.classification;
    if (c.brand != null && c.brand!.isNotEmpty) return c.brand!;
    if (c.category != OtpCategory.unknown) return c.category.label;
    return c.sms.sender;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = entry.classification;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            CategoryAvatar(category: c.category, size: 44),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.ruleName == null
                        ? relativeTime(entry.at)
                        : '${relativeTime(entry.at)} · ${entry.ruleName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: t.textTertiary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusPill(
                  label: entry.outcome.label,
                  tone: entry.outcome.tone,
                  dense: true,
                ),
                if (c.hasOtp) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    maskOtp(c.otp!),
                    style: MonoText.otp(context, size: 12)
                        .copyWith(color: t.textSecondary),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
