import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:otpbridge/app/providers.dart';
import 'package:otpbridge/app/router.dart';
import 'package:otpbridge/core/theme/app_colors.dart';
import 'package:otpbridge/core/theme/app_spacing.dart';
import 'package:otpbridge/core/theme/app_theme.dart';
import 'package:otpbridge/core/widgets/widgets.dart';
import 'package:otpbridge/domain/models/models.dart';

/// Pushes the manual-forward screen. This path needs NO SMS permission — the
/// user pastes or types a message, OTPBridge detects the code on-device and
/// forwards it through the same offline queue used for automatic forwards.
void openManualForward(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const ManualForwardScreen()),
  );
}

/// Forward an OTP by hand, with zero SMS permission. The user pastes the
/// message (or types the code), OTPBridge classifies it locally and shows what
/// will be sent, then enqueues one forward per selected recipient.
class ManualForwardScreen extends ConsumerStatefulWidget {
  const ManualForwardScreen({super.key});

  @override
  ConsumerState<ManualForwardScreen> createState() =>
      _ManualForwardScreenState();
}

class _ManualForwardScreenState extends ConsumerState<ManualForwardScreen> {
  static const _uuid = Uuid();

  final _bodyController = TextEditingController();
  final _senderController = TextEditingController();
  final _selectedIds = <String>{};

  SmsClassification? _classification;
  bool _sending = false;

  @override
  void dispose() {
    _bodyController.dispose();
    _senderController.dispose();
    super.dispose();
  }

  /// Runs the on-device classifier over the current fields so the user can see
  /// the extracted OTP / brand / category before sending.
  void _detect() {
    final body = _bodyController.text.trim();
    if (body.isEmpty) {
      setState(() => _classification = null);
      return;
    }
    final sms = IncomingSms(
      id: _uuid.v4(),
      sender: _senderController.text.trim(),
      body: body,
      receivedAt: DateTime.now(),
    );
    setState(() {
      _classification = ref.read(classificationEngineProvider).classifySync(sms);
    });
  }

  void _toggleRecipient(String id) {
    setState(() {
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
    });
  }

  String _previewMessage(SmsClassification c) {
    final brand = c.brand ?? c.category.label;
    final otp = c.otp ?? '(see message)';
    final amount =
        c.amount != null ? ' · Amount ₹${c.amount!.toStringAsFixed(0)}' : '';
    return 'OTPBridge · $brand OTP: $otp$amount';
  }

  Future<void> _forward(List<Recipient> recipients) async {
    final body = _bodyController.text.trim();
    final messenger = ScaffoldMessenger.of(context);

    if (body.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Paste or type the OTP message first')),
      );
      return;
    }
    final selected =
        recipients.where((r) => _selectedIds.contains(r.id)).toList();
    if (selected.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Pick at least one recipient')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final sms = IncomingSms(
        id: _uuid.v4(),
        sender: _senderController.text.trim(),
        body: body,
        receivedAt: DateTime.now(),
      );
      final classification =
          ref.read(classificationEngineProvider).classifySync(sms);

      final decision = RuleDecision(
        kind: DecisionKind.forward,
        recipientIds: selected.map((r) => r.id).toList(),
        reason: 'Manual forward',
      );

      // Same offline-first path the automatic pipeline uses: enqueue one task
      // per recipient, then flush immediately. The queue writes its own
      // forwarded/failed history entries; we add a "queued" marker up front so
      // the manual action is visible in History straight away.
      final queue = ref.read(forwardingQueueProvider);
      await queue.enqueueForDecision(
        classification: classification,
        decision: decision,
        recipients: selected,
      );
      await _recordQueued(classification, selected);
      await queue.processDue();

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            selected.length == 1
                ? 'Forwarding to ${selected.first.name}'
                : 'Forwarding to ${selected.length} recipients',
          ),
        ),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _recordQueued(
    SmsClassification classification,
    List<Recipient> recipients,
  ) async {
    final entry = HistoryEntry(
      id: _uuid.v4(),
      at: DateTime.now(),
      classification: classification,
      outcome: OtpOutcome.queued,
      ruleName: 'Manual forward',
      recipientNames: recipients.map((r) => r.name).toList(),
      detail: 'Queued to ${recipients.length} recipient'
          '${recipients.length == 1 ? '' : 's'}',
    );
    await ref.read(historyRepositoryProvider).add(entry);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final recipients =
        ref.watch(recipientsProvider).valueOrNull ?? const <Recipient>[];
    final hasText = _bodyController.text.trim().isNotEmpty;
    final canForward = hasText && _selectedIds.isNotEmpty && !_sending;

    return Scaffold(
      appBar: AppBar(title: const Text('Manual forward')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.md,
          AppSpacing.screenH,
          AppSpacing.xxl,
        ),
        children: [
          _Intro(),
          const SizedBox(height: AppSpacing.lg),
          _messageField(),
          const SizedBox(height: AppSpacing.sm),
          _senderField(),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: hasText
                  ? () {
                      FocusScope.of(context).unfocus();
                      _detect();
                    }
                  : null,
              icon: const Icon(Icons.auto_awesome_outlined, size: 18),
              label: const Text('Detect code'),
            ),
          ),
          if (_classification != null) ...[
            const SizedBox(height: AppSpacing.xs),
            _DetectionCard(
              classification: _classification!,
              preview: _previewMessage(_classification!),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          _recipientsSection(context, recipients),
        ],
      ),
      bottomNavigationBar: _forwardBar(context, t, recipients, canForward),
    );
  }

  Widget _messageField() {
    return TextField(
      controller: _bodyController,
      onChanged: (_) => _detect(),
      minLines: 4,
      maxLines: 8,
      textInputAction: TextInputAction.newline,
      keyboardType: TextInputType.multiline,
      decoration: const InputDecoration(
        labelText: 'Paste the OTP message',
        hintText: 'e.g. 481920 is your verification code for Amazon',
        alignLabelWithHint: true,
      ),
    );
  }

  Widget _senderField() {
    return TextField(
      controller: _senderController,
      onChanged: (_) => _detect(),
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(
        labelText: 'Sender (optional)',
        hintText: 'e.g. AMAZON or a short code',
        prefixIcon: Icon(Icons.badge_outlined),
      ),
    );
  }

  Widget _recipientsSection(
    BuildContext context,
    List<Recipient> recipients,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Send to',
          subtitle: _selectedIds.isEmpty
              ? 'Choose one or more recipients'
              : '${_selectedIds.length} selected',
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          trailing: TextButton.icon(
            onPressed: () => context.push(Routes.recipients),
            icon: const Icon(Icons.person_add_alt_outlined, size: 18),
            label: const Text('Add'),
          ),
        ),
        if (recipients.isEmpty)
          GlassCard(
            child: EmptyState(
              icon: Icons.people_alt_outlined,
              title: 'No recipients yet',
              message: 'Add someone you trust to forward this OTP to.',
              action: FilledButton.icon(
                onPressed: () => context.push(Routes.recipients),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, AppSpacing.touchTarget),
                ),
                icon: const Icon(Icons.person_add_alt_outlined, size: 20),
                label: const Text('Add recipient'),
              ),
            ),
          )
        else
          for (final r in recipients) ...[
            _RecipientTile(
              recipient: r,
              selected: _selectedIds.contains(r.id),
              onTap: () => _toggleRecipient(r.id),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }

  Widget _forwardBar(
    BuildContext context,
    AppTokens t,
    List<Recipient> recipients,
    bool canForward,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.sm,
          AppSpacing.screenH,
          AppSpacing.sm,
        ),
        child: FilledButton.icon(
          onPressed: canForward ? () => _forward(recipients) : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, AppSpacing.touchTarget),
          ),
          icon: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded, size: 20),
          label: Text(_sending ? 'Forwarding…' : 'Forward now'),
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, size: 20, color: t.success),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'No SMS permission needed. Paste a message, and OTPBridge will '
              'detect the code on your device and forward it to the people '
              'you pick.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: t.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Read-only preview of what the classifier extracted, plus the exact message
/// that will be sent to each recipient.
class _DetectionCard extends StatelessWidget {
  const _DetectionCard({required this.classification, required this.preview});

  final SmsClassification classification;
  final String preview;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final c = classification;
    final hasOtp = c.hasOtp;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryAvatar(category: c.category, size: 40),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.brand ?? c.category.label, style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      c.category.label,
                      style:
                          text.bodySmall?.copyWith(color: t.textTertiary),
                    ),
                  ],
                ),
              ),
              if (hasOtp)
                const StatusPill(
                  label: 'Code found',
                  tone: PillTone.success,
                  icon: Icons.check_circle_outline_rounded,
                  dense: true,
                )
              else
                const StatusPill(
                  label: 'No code',
                  tone: PillTone.warning,
                  icon: Icons.error_outline_rounded,
                  dense: true,
                ),
            ],
          ),
          if (hasOtp) ...[
            const SizedBox(height: AppSpacing.md),
            Text(c.otp!, style: MonoText.otp(context, size: 26)),
          ],
          const SizedBox(height: AppSpacing.md),
          Text('Will be sent as',
              style: text.labelMedium?.copyWith(color: t.textTertiary)),
          const SizedBox(height: AppSpacing.xs),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: t.surfaceSunken,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              preview,
              style: text.bodyMedium?.copyWith(color: t.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipientTile extends StatelessWidget {
  const _RecipientTile({
    required this.recipient,
    required this.selected,
    required this.onTap,
  });

  final Recipient recipient;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return GlassCard(
      onTap: onTap,
      borderColor: selected ? t.primary : null,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.primarySubtle,
              shape: BoxShape.circle,
            ),
            child: Text(
              recipient.initials,
              style: text.titleMedium?.copyWith(
                color: t.onPrimarySubtle,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recipient.name,
                    style: text.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  recipient.phone,
                  style: text.bodySmall?.copyWith(color: t.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            selected
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: selected ? t.primary : t.textTertiary,
          ),
        ],
      ),
    );
  }
}
