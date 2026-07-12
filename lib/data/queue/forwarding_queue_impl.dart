import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/services/forward_channel_plugin.dart';
import '../../domain/services/notification_service.dart';
import '../../domain/services/service_contracts.dart';
import '../../domain/services/sms_gateway.dart';

/// Offline-first forwarding queue.
///
/// Tasks are persisted immediately on enqueue and drained by [processDue],
/// which is invoked opportunistically by the pipeline and periodically by the
/// [start]ed background timer. Retry timing (exponential backoff) and the
/// attempt cap come from [ForwardTask] itself.
class DefaultForwardingQueue implements ForwardingQueue {
  DefaultForwardingQueue({
    required QueueRepository queueRepo,
    required HistoryRepository historyRepo,
    required ChannelRegistry channels,
    required NotificationService notifications,
    Uuid uuid = const Uuid(),
    DateTime Function() clock = DateTime.now,
  })  : _queueRepo = queueRepo,
        _historyRepo = historyRepo,
        _channels = channels,
        _notifications = notifications,
        _uuid = uuid,
        _clock = clock;

  /// How often the background worker drains the queue.
  static const Duration tickInterval = Duration(seconds: 30);

  final QueueRepository _queueRepo;
  final HistoryRepository _historyRepo;
  final ChannelRegistry _channels;
  final NotificationService _notifications;
  final Uuid _uuid;
  final DateTime Function() _clock;

  Timer? _timer;
  bool _draining = false;

  @override
  Future<List<ForwardTask>> enqueueForDecision({
    required SmsClassification classification,
    required RuleDecision decision,
    required List<Recipient> recipients,
  }) async {
    final now = _clock();
    final seenRecipientIds = <String>{};
    final tasks = <ForwardTask>[];

    for (final recipient in recipients) {
      // Duplicate protection: never double-queue the same person for one OTP.
      if (!seenRecipientIds.add(recipient.id)) continue;

      final task = ForwardTask(
        id: _uuid.v4(),
        classification: classification,
        recipientId: recipient.id,
        recipientName: recipient.name,
        destination: _destinationFor(recipient),
        channel: recipient.preferredChannel,
        ruleId: decision.rule?.id,
        createdAt: now,
      );
      await _queueRepo.save(task);
      tasks.add(task);
    }
    return tasks;
  }

  @override
  Future<void> enqueueTask(ForwardTask task) => _queueRepo.save(task);

  @override
  Future<void> processDue() async {
    // Re-entrancy guard: the timer tick and an opportunistic flush from the
    // pipeline must not double-deliver the same task.
    if (_draining) return;
    _draining = true;
    try {
      final due = await _queueRepo.getPending(_clock());
      for (final task in due) {
        try {
          await _processTask(task);
        } catch (e) {
          // One bad task must never stall the batch; record it as a failed
          // attempt (best-effort) and move on.
          try {
            await _recordFailure(task, 'Unexpected error: $e');
          } catch (_) {
            // Repository unavailable — nothing more we can do this tick.
          }
        }
      }
    } finally {
      _draining = false;
    }
  }

  @override
  void start() {
    stop(); // idempotent: never stack timers
    _timer = Timer.periodic(tickInterval, (_) => processDue());
  }

  @override
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  Future<void> _processTask(ForwardTask task) async {
    if (task.isTerminal) return;

    final sending = task.copyWith(status: ForwardStatus.sending);
    await _queueRepo.save(sending);

    final plugin = _channels.forChannel(sending.channel);
    if (plugin == null) {
      await _recordFailure(
          sending, 'No ${sending.channel.label} channel registered');
      return;
    }
    if (!await plugin.isAvailable()) {
      await _recordFailure(
          sending, '${sending.channel.label} channel unavailable');
      return;
    }

    SmsSendResult result;
    try {
      result = await plugin.deliver(sending);
    } catch (e) {
      result = SmsSendResult.fail('$e');
    }

    if (result.success) {
      await _recordSuccess(sending);
    } else {
      await _recordFailure(sending, result.error ?? 'Delivery failed');
    }
  }

  Future<void> _recordSuccess(ForwardTask task) async {
    final now = _clock();
    final sent = task.copyWith(status: ForwardStatus.sent, sentAt: now);
    await _queueRepo.save(sent);

    // No delivery receipts in v1: sent == delivered. Terminal tasks stay in
    // the repo; getPending filters them and the UI can show/clear them.
    final delivered =
        sent.copyWith(status: ForwardStatus.delivered, deliveredAt: now);
    await _queueRepo.save(delivered);

    final entry = _historyFor(delivered, OtpOutcome.forwarded,
        detail: 'Forwarded to ${delivered.recipientName} '
            'via ${delivered.channel.label}');
    await _historyRepo.add(entry);
    await _notifications.showForwarded(entry);
  }

  Future<void> _recordFailure(ForwardTask task, String error) async {
    final now = _clock();
    var failed = task.copyWith(
      status: ForwardStatus.failed,
      attempts: task.attempts + 1,
      lastError: error,
    );

    if (failed.isTerminal) {
      // Out of attempts: terminal-failed. Record the final outcome.
      await _queueRepo.save(failed);
      await _historyRepo.add(_historyFor(failed, OtpOutcome.failed,
          detail: 'Gave up after ${failed.attempts} attempts: $error'));
      return;
    }

    failed = failed.copyWith(nextAttemptAt: now.add(failed.backoff));
    await _queueRepo.save(failed);
    await _notifications.showRetrying(failed);
  }

  HistoryEntry _historyFor(ForwardTask task, OtpOutcome outcome,
          {String? detail}) =>
      HistoryEntry(
        id: _uuid.v4(),
        at: _clock(),
        classification: task.classification,
        outcome: outcome,
        ruleId: task.ruleId,
        recipientNames: [task.recipientName],
        detail: detail,
      );

  String _destinationFor(Recipient recipient) =>
      switch (recipient.preferredChannel) {
        // Email delivers to the address; everything else rides the phone
        // number (SMS/WhatsApp/Telegram/push all key off it in v1).
        ForwardChannel.email => recipient.email ?? recipient.phone,
        _ => recipient.phone,
      };
}
