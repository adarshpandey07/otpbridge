import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:otpbridge/app/providers.dart';
import 'package:otpbridge/core/theme/app_colors.dart';
import 'package:otpbridge/core/theme/app_spacing.dart';
import 'package:otpbridge/core/theme/app_theme.dart';
import 'package:otpbridge/core/widgets/widgets.dart';
import 'package:otpbridge/domain/models/models.dart';

/// Presents a high-risk OTP for the user's decision in a modal bottom
/// sheet. Approve forwards it, Reject discards it, Cancel dismisses
/// without deciding. Auto-closes when the approval expires.
///
/// The sheet content is a [ConsumerStatefulWidget] so it can obtain a
/// [WidgetRef] from the ambient [ProviderScope] — this function only
/// receives a [BuildContext].
Future<void> showApprovalSheet(
  BuildContext context,
  PendingApproval approval,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ApprovalSheetContent(approval: approval),
  );
}

class _ApprovalSheetContent extends ConsumerStatefulWidget {
  const _ApprovalSheetContent({required this.approval});

  final PendingApproval approval;

  @override
  ConsumerState<_ApprovalSheetContent> createState() =>
      _ApprovalSheetContentState();
}

class _ApprovalSheetContentState extends ConsumerState<_ApprovalSheetContent> {
  static final NumberFormat _rupees =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _busy = false;
  bool _closed = false;

  PendingApproval get _approval => widget.approval;

  @override
  void initState() {
    super.initState();
    _remaining = _timeLeft();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    if (_remaining <= Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _expire());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Duration _timeLeft() {
    final left = _approval.expiresAt.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  void _tick() {
    if (_busy) return;
    final left = _timeLeft();
    if (left <= Duration.zero) {
      _expire();
    } else if (mounted) {
      setState(() => _remaining = left);
    }
  }

  void _expire() {
    if (_closed || !mounted) return;
    _closed = true;
    _timer?.cancel();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(const SnackBar(
      content: Text('Approval expired — the OTP was not forwarded'),
    ));
  }

  Future<void> _decide({required bool approve}) async {
    if (_busy || _closed) return;
    setState(() => _busy = true);
    try {
      final pipeline = ref.read(smsPipelineProvider);
      if (approve) {
        await pipeline.approve(_approval);
      } else {
        await pipeline.reject(_approval);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Something went wrong — please try again'),
      ));
      return;
    }
    if (!mounted || _closed) return;
    _closed = true;
    _timer?.cancel();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(
      content: Text(approve
          ? 'Approved — OTP queued for forwarding'
          : 'Rejected — the OTP was not forwarded'),
    ));
  }

  void _cancel() {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    Navigator.of(context).pop();
  }

  double get _progress {
    final total =
        _approval.expiresAt.difference(_approval.createdAt).inSeconds;
    if (total <= 0) return 0;
    return (_remaining.inSeconds / total).clamp(0.0, 1.0);
  }

  String get _countdownLabel {
    final m = _remaining.inMinutes;
    final s = _remaining.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String get _recipientsLabel {
    final recipients =
        ref.watch(recipientsProvider).valueOrNull ?? const <Recipient>[];
    final names = _approval.recipientIds
        .map((id) => recipients.firstWhereOrNull((r) => r.id == id)?.name)
        .whereType<String>()
        .toList();
    if (names.isNotEmpty) return names.join(', ');
    if (_approval.recipientIds.isEmpty) return 'Default recipient';
    return '${_approval.recipientIds.length} recipient'
        '${_approval.recipientIds.length == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final c = _approval.classification;
    final urgent = _remaining.inSeconds <= 30;
    final countdownColor = urgent ? t.danger : t.warning;
    final isHighRisk = c.category.risk == RiskTier.high;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        0,
        AppSpacing.screenH,
        AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ────────────────────────────────────────────────────
          Row(
            children: [
              CategoryAvatar(category: c.category, size: 48),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.brand ?? c.merchant ?? c.sms.sender,
                      style: text.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c.category.label,
                      style: text.bodySmall?.copyWith(color: t.textTertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusPill(
                label: isHighRisk ? 'High risk' : 'Needs approval',
                tone: isHighRisk ? PillTone.danger : PillTone.warning,
                icon: Icons.gpp_maybe_outlined,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── OTP ───────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            decoration: BoxDecoration(
              color: t.surfaceSunken,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: t.border),
            ),
            child: Column(
              children: [
                Text(
                  'ONE-TIME PASSCODE',
                  style: text.labelSmall?.copyWith(letterSpacing: 1.2),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  c.otp ?? '——',
                  textAlign: TextAlign.center,
                  style: MonoText.otp(context, size: 32),
                ),
              ],
            ),
          ),

          // ── Risk context: amount + reason ─────────────────────────────
          if (c.amount != null || _approval.reason != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: t.warningSubtle,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (c.amount != null)
                    Row(
                      children: [
                        Icon(Icons.currency_rupee_rounded,
                            size: 18, color: t.warning),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Amount',
                          style: text.labelMedium?.copyWith(color: t.warning),
                        ),
                        const Spacer(),
                        Text(
                          _rupees.format(c.amount),
                          style: MonoText.amount(context, size: 16)
                              .copyWith(color: t.warning),
                        ),
                      ],
                    ),
                  if (c.amount != null && _approval.reason != null)
                    const SizedBox(height: AppSpacing.xs),
                  if (_approval.reason != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 18, color: t.warning),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            _approval.reason!,
                            style:
                                text.bodySmall?.copyWith(color: t.warning),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),

          // ── Details ───────────────────────────────────────────────────
          if (c.merchant != null)
            _DetailRow(label: 'Merchant', value: c.merchant!),
          if (_approval.ruleName != null)
            _DetailRow(label: 'Rule', value: _approval.ruleName!),
          _DetailRow(label: 'Forward to', value: _recipientsLabel),
          const SizedBox(height: AppSpacing.lg),

          // ── Countdown ─────────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 16, color: countdownColor),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Expires in $_countdownLabel',
                style: text.labelMedium?.copyWith(color: countdownColor),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 6,
              color: countdownColor,
              backgroundColor: t.surfaceSunken,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Actions ───────────────────────────────────────────────────
          FilledButton(
            onPressed: _busy ? null : () => _decide(approve: true),
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Text('Approve & forward'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: _busy ? null : () => _decide(approve: false),
            style: OutlinedButton.styleFrom(
              foregroundColor: t.danger,
              side: BorderSide(color: t.danger.withValues(alpha: 0.45)),
            ),
            child: const Text('Reject'),
          ),
          const SizedBox(height: AppSpacing.xxs),
          TextButton(
            onPressed: _busy ? null : _cancel,
            style: TextButton.styleFrom(
              foregroundColor: t.textSecondary,
              minimumSize: const Size.fromHeight(AppSpacing.touchTarget),
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

/// A quiet label/value row for approval metadata.
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: text.labelMedium?.copyWith(color: t.textTertiary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              value,
              style: text.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
