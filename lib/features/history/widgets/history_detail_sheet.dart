import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:otpbridge/core/theme/app_colors.dart';
import 'package:otpbridge/core/theme/app_spacing.dart';
import 'package:otpbridge/core/theme/app_theme.dart';
import 'package:otpbridge/core/widgets/widgets.dart';
import 'package:otpbridge/domain/models/models.dart';
import 'package:otpbridge/features/dashboard/widgets/activity_row.dart';

/// Opens the full-detail bottom sheet for one [HistoryEntry].
void showHistoryDetail(BuildContext context, HistoryEntry entry) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _HistoryDetailSheet(entry: entry),
  );
}

class _HistoryDetailSheet extends StatelessWidget {
  const _HistoryDetailSheet({required this.entry});

  final HistoryEntry entry;

  String get _title {
    final c = entry.classification;
    if (c.brand != null && c.brand!.isNotEmpty) return c.brand!;
    if (c.category != OtpCategory.unknown) return c.category.label;
    return c.sms.sender;
  }

  static String _formatAmount(double amount) {
    final format = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: amount == amount.roundToDouble() ? 0 : 2,
    );
    return format.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = entry.classification;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.xs,
          AppSpacing.screenH,
          AppSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CategoryAvatar(category: c.category, size: 48),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall,
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
                StatusPill(
                  label: entry.outcome.label,
                  tone: entry.outcome.tone,
                ),
              ],
            ),
            if (c.hasOtp) ...[
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: t.surfaceSunken,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: t.border),
                ),
                child: Column(
                  children: [
                    SelectableText(
                      c.otp!,
                      textAlign: TextAlign.center,
                      style: MonoText.otp(context, size: 30),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'One-time password',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: t.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text('Details', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            _DetailRow(label: 'Sender', value: c.sms.sender),
            _DetailRow(label: 'Category', value: c.category.label),
            if (c.brand != null && c.brand!.isNotEmpty)
              _DetailRow(label: 'Brand', value: c.brand!),
            if (c.merchant != null && c.merchant!.isNotEmpty)
              _DetailRow(label: 'Merchant', value: c.merchant!),
            if (c.amount != null)
              _DetailRow(
                label: 'Amount',
                child: Text(
                  _formatAmount(c.amount!),
                  style: MonoText.amount(context),
                ),
              ),
            _DetailRow(
              label: 'Confidence',
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: LinearProgressIndicator(
                        value: c.confidence.clamp(0, 1),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '${(c.confidence * 100).round()}%',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            if (entry.ruleName != null)
              _DetailRow(label: 'Rule', value: entry.ruleName!),
            if (entry.recipientNames.isNotEmpty)
              _DetailRow(
                label: 'Recipients',
                value: entry.recipientNames.join(', '),
              ),
            _DetailRow(
              label: 'Outcome',
              child: StatusPill(
                label: entry.outcome.label,
                tone: entry.outcome.tone,
                dense: true,
              ),
            ),
            _DetailRow(
              label: 'Time',
              value: DateFormat('EEE, d MMM yyyy · h:mm a').format(entry.at),
            ),
            if (entry.detail != null && entry.detail!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: t.surfaceSunken,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  entry.detail!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: t.textSecondary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, this.value, this.child})
      : assert(value != null || child != null);

  final String label;
  final String? value;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: t.textTertiary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: child ??
                Text(value!, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
