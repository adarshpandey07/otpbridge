import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:otpbridge/data/queue/forwarding_queue_impl.dart';
import 'package:otpbridge/domain/models/models.dart';
import 'package:otpbridge/domain/repositories/repositories.dart';
import 'package:otpbridge/domain/services/forward_channel_plugin.dart';
import 'package:otpbridge/domain/services/notification_service.dart';
import 'package:otpbridge/domain/services/sms_gateway.dart';
import 'package:uuid/uuid.dart';

/// ── Fakes ───────────────────────────────────────────────────────────────────

class InMemoryQueueRepository implements QueueRepository {
  final Map<String, ForwardTask> tasks = {};
  final Set<String> fingerprints = {};

  @override
  Future<List<ForwardTask>> getAll() async => tasks.values.toList();

  @override
  Future<List<ForwardTask>> getPending(DateTime now) async => tasks.values
      .where((t) =>
          !t.isTerminal &&
          (t.status == ForwardStatus.queued ||
              t.status == ForwardStatus.failed) &&
          (t.nextAttemptAt == null || !t.nextAttemptAt!.isAfter(now)))
      .toList();

  @override
  Future<void> save(ForwardTask task) async => tasks[task.id] = task;

  @override
  Future<void> remove(String id) async => tasks.remove(id);

  @override
  Future<bool> hasFingerprint(String fingerprint) async =>
      fingerprints.contains(fingerprint);

  @override
  Future<void> rememberFingerprint(String fingerprint) async =>
      fingerprints.add(fingerprint);

  @override
  Stream<List<ForwardTask>> watch() => const Stream.empty();
}

class InMemoryHistoryRepository implements HistoryRepository {
  final List<HistoryEntry> entries = [];

  @override
  Future<List<HistoryEntry>> getAll({int? limit}) async {
    final sorted = [...entries]..sort((a, b) => b.at.compareTo(a.at));
    return limit == null ? sorted : sorted.take(limit).toList();
  }

  @override
  Future<void> add(HistoryEntry entry) async => entries.add(entry);

  @override
  Future<void> update(HistoryEntry entry) async {
    final i = entries.indexWhere((e) => e.id == entry.id);
    if (i >= 0) entries[i] = entry;
  }

  @override
  Future<void> clear() async => entries.clear();

  @override
  Stream<List<HistoryEntry>> watch() => const Stream.empty();
}

/// Channel plugin that can be toggled to succeed or fail, and records
/// every task it was asked to deliver.
class FakeChannelPlugin implements ForwardChannelPlugin {
  FakeChannelPlugin({this.channel = ForwardChannel.sms});

  @override
  final ForwardChannel channel;

  bool available = true;
  bool succeed = true;
  String failError = 'radio off';
  final List<ForwardTask> delivered = [];

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<SmsSendResult> deliver(ForwardTask task) async {
    delivered.add(task);
    return succeed
        ? const SmsSendResult.ok()
        : SmsSendResult.fail(failError);
  }
}

class RecordingNotificationService extends NoopNotificationService {
  final List<ForwardTask> retrying = [];
  final List<HistoryEntry> forwarded = [];

  @override
  Future<void> showRetrying(ForwardTask task) async => retrying.add(task);

  @override
  Future<void> showForwarded(HistoryEntry entry, {bool maskOtp = true}) async =>
      forwarded.add(entry);
}

/// ── Fixtures ────────────────────────────────────────────────────────────────

final _t0 = DateTime(2026, 7, 12, 10, 0, 0);

SmsClassification classification() => SmsClassification(
      sms: IncomingSms(
        id: 'sms-1',
        sender: 'AX-HDFCBK',
        body: 'Your OTP is 482913',
        receivedAt: _t0,
      ),
      category: OtpCategory.bankingLogin,
      confidence: 0.95,
      otp: '482913',
      brand: 'HDFC Bank',
    );

Recipient recipient(String id, {ForwardChannel channel = ForwardChannel.sms}) =>
    Recipient(
      id: id,
      name: 'Person $id',
      phone: '+9199000000$id',
      email: 'p$id@example.com',
      preferredChannel: channel,
    );

RuleDecision decision() => RuleDecision(
      kind: DecisionKind.forward,
      rule: const ForwardRule(id: 'rule-1', name: 'Banking to family'),
      recipientIds: const ['1', '2'],
    );

/// Test harness bundling the queue with all its fakes and a mutable clock.
class Harness {
  Harness() {
    queue = DefaultForwardingQueue(
      queueRepo: repo,
      historyRepo: history,
      channels: ChannelRegistry([plugin]),
      notifications: notifications,
      uuid: const Uuid(),
      clock: () => now,
    );
  }

  final repo = InMemoryQueueRepository();
  final history = InMemoryHistoryRepository();
  final plugin = FakeChannelPlugin();
  final notifications = RecordingNotificationService();
  DateTime now = _t0;
  late final DefaultForwardingQueue queue;

  void advance(Duration d) => now = now.add(d);
}

void main() {
  group('enqueueForDecision', () {
    test('creates one task per recipient with correct fields', () async {
      final h = Harness();
      final tasks = await h.queue.enqueueForDecision(
        classification: classification(),
        decision: decision(),
        recipients: [recipient('1'), recipient('2')],
      );

      expect(tasks, hasLength(2));
      expect(h.repo.tasks, hasLength(2));
      final task = tasks.first;
      expect(task.status, ForwardStatus.queued);
      expect(task.attempts, 0);
      expect(task.createdAt, _t0);
      expect(task.ruleId, 'rule-1');
      expect(task.channel, ForwardChannel.sms);
      expect(task.destination, recipient('1').phone);
      expect(task.recipientId, '1');
      expect(task.recipientName, 'Person 1');
    });

    test('dedups duplicate recipients by id', () async {
      final h = Harness();
      final tasks = await h.queue.enqueueForDecision(
        classification: classification(),
        decision: decision(),
        recipients: [recipient('1'), recipient('1'), recipient('2')],
      );

      expect(tasks, hasLength(2));
      expect(tasks.map((t) => t.recipientId), ['1', '2']);
      expect(h.repo.tasks, hasLength(2));
    });

    test('uses email as destination for email channel', () async {
      final h = Harness();
      final tasks = await h.queue.enqueueForDecision(
        classification: classification(),
        decision: decision(),
        recipients: [recipient('7', channel: ForwardChannel.email)],
      );

      expect(tasks.single.channel, ForwardChannel.email);
      expect(tasks.single.destination, 'p7@example.com');
    });
  });

  group('enqueueTask', () {
    test('persists the task as-is', () async {
      final h = Harness();
      final task = ForwardTask(
        id: 'manual-1',
        classification: classification(),
        recipientId: '1',
        recipientName: 'Person 1',
        destination: '+91990000001',
        channel: ForwardChannel.sms,
        createdAt: _t0,
      );

      await h.queue.enqueueTask(task);
      expect(h.repo.tasks['manual-1'], task);
    });
  });

  group('processDue — success path', () {
    test('delivers a queued task and marks it delivered', () async {
      final h = Harness();
      await h.queue.enqueueForDecision(
        classification: classification(),
        decision: decision(),
        recipients: [recipient('1')],
      );

      await h.queue.processDue();

      expect(h.plugin.delivered, hasLength(1));
      final stored = h.repo.tasks.values.single;
      expect(stored.status, ForwardStatus.delivered);
      expect(stored.sentAt, h.now);
      expect(stored.deliveredAt, h.now);
      expect(stored.isTerminal, isTrue);
      // Delivered task is no longer pending.
      expect(await h.repo.getPending(h.now), isEmpty);
      // A forwarded history entry was recorded and notified.
      expect(h.history.entries.single.outcome, OtpOutcome.forwarded);
      expect(h.notifications.forwarded, hasLength(1));
    });

    test('is idempotent — a second pass does not re-deliver', () async {
      final h = Harness();
      await h.queue.enqueueForDecision(
        classification: classification(),
        decision: decision(),
        recipients: [recipient('1')],
      );

      await h.queue.processDue();
      await h.queue.processDue();

      expect(h.plugin.delivered, hasLength(1));
      expect(h.history.entries, hasLength(1));
    });
  });

  group('processDue — failure and retry', () {
    test(
        'failing delivery increments attempts, schedules a future retry, '
        'and notifies retrying', () async {
      final h = Harness();
      h.plugin.succeed = false;
      await h.queue.enqueueForDecision(
        classification: classification(),
        decision: decision(),
        recipients: [recipient('1')],
      );

      await h.queue.processDue();

      final stored = h.repo.tasks.values.single;
      expect(stored.status, ForwardStatus.failed);
      expect(stored.attempts, 1);
      expect(stored.lastError, 'radio off');
      expect(stored.nextAttemptAt, isNotNull);
      expect(stored.nextAttemptAt!.isAfter(h.now), isTrue);
      expect(stored.isTerminal, isFalse);
      expect(h.notifications.retrying, hasLength(1));
    });

    test('getPending respects nextAttemptAt — future retry is not due',
        () async {
      final h = Harness();
      h.plugin.succeed = false;
      await h.queue.enqueueForDecision(
        classification: classification(),
        decision: decision(),
        recipients: [recipient('1')],
      );

      await h.queue.processDue(); // fails, schedules retry in the future

      // Still before nextAttemptAt: nothing is due, nothing gets delivered.
      expect(await h.repo.getPending(h.now), isEmpty);
      await h.queue.processDue();
      expect(h.plugin.delivered, hasLength(1));

      // Advance past the backoff: due again.
      final retryAt = h.repo.tasks.values.single.nextAttemptAt!;
      h.now = retryAt;
      expect(await h.repo.getPending(h.now), hasLength(1));
      await h.queue.processDue();
      expect(h.plugin.delivered, hasLength(2));
    });

    test('stays non-terminal until maxAttempts, then terminal-failed',
        () async {
      final h = Harness();
      h.plugin.succeed = false;
      await h.queue.enqueueForDecision(
        classification: classification(),
        decision: decision(),
        recipients: [recipient('1')],
      );

      for (var attempt = 1; attempt <= ForwardTask.maxAttempts; attempt++) {
        await h.queue.processDue();
        final stored = h.repo.tasks.values.single;
        expect(stored.attempts, attempt);
        expect(stored.isTerminal, attempt >= ForwardTask.maxAttempts,
            reason: 'attempt $attempt');
        if (stored.nextAttemptAt != null &&
            stored.nextAttemptAt!.isAfter(h.now)) {
          h.now = stored.nextAttemptAt!;
        }
      }

      final dead = h.repo.tasks.values.single;
      expect(dead.status, ForwardStatus.failed);
      expect(dead.attempts, ForwardTask.maxAttempts);
      expect(dead.isTerminal, isTrue);
      // Retrying was notified for every non-terminal failure only.
      expect(h.notifications.retrying, hasLength(ForwardTask.maxAttempts - 1));
      // Terminal failure recorded in history.
      expect(h.history.entries.single.outcome, OtpOutcome.failed);

      // Dead task is never picked up again, even far in the future.
      h.advance(const Duration(days: 1));
      expect(await h.repo.getPending(h.now), isEmpty);
      final deliveredBefore = h.plugin.delivered.length;
      await h.queue.processDue();
      expect(h.plugin.delivered.length, deliveredBefore);
    });

    test('backoff grows between consecutive failures', () async {
      final h = Harness();
      h.plugin.succeed = false;
      await h.queue.enqueueForDecision(
        classification: classification(),
        decision: decision(),
        recipients: [recipient('1')],
      );

      await h.queue.processDue();
      final first = h.repo.tasks.values.single.nextAttemptAt!;
      final firstDelay = first.difference(h.now);

      h.now = first;
      await h.queue.processDue();
      final second = h.repo.tasks.values.single.nextAttemptAt!;
      final secondDelay = second.difference(h.now);

      expect(secondDelay, greaterThan(firstDelay));
    });

    test('missing channel plugin counts as a failed attempt', () async {
      final h = Harness();
      // WhatsApp recipient, but only the SMS plugin is registered.
      await h.queue.enqueueForDecision(
        classification: classification(),
        decision: decision(),
        recipients: [recipient('1', channel: ForwardChannel.whatsapp)],
      );

      await h.queue.processDue();

      final stored = h.repo.tasks.values.single;
      expect(stored.status, ForwardStatus.failed);
      expect(stored.attempts, 1);
      expect(stored.lastError, contains('WhatsApp'));
      expect(h.plugin.delivered, isEmpty);
      expect(h.notifications.retrying, hasLength(1));
    });

    test('unavailable plugin counts as a failed attempt', () async {
      final h = Harness();
      h.plugin.available = false;
      await h.queue.enqueueForDecision(
        classification: classification(),
        decision: decision(),
        recipients: [recipient('1')],
      );

      await h.queue.processDue();

      final stored = h.repo.tasks.values.single;
      expect(stored.status, ForwardStatus.failed);
      expect(stored.attempts, 1);
      expect(h.plugin.delivered, isEmpty);
    });

    test('a throwing plugin does not stall the batch', () async {
      final h = Harness();
      final throwing = _ThrowingPlugin();
      final queue = DefaultForwardingQueue(
        queueRepo: h.repo,
        historyRepo: h.history,
        channels: ChannelRegistry([throwing]),
        notifications: h.notifications,
        clock: () => h.now,
      );
      await queue.enqueueForDecision(
        classification: classification(),
        decision: decision(),
        recipients: [recipient('1'), recipient('2')],
      );

      await queue.processDue(); // must not throw

      final stored = h.repo.tasks.values.toList();
      expect(stored, hasLength(2));
      for (final t in stored) {
        expect(t.status, ForwardStatus.failed);
        expect(t.attempts, 1);
        expect(t.lastError, contains('boom'));
      }
    });
  });

  group('start/stop', () {
    test('start is idempotent and stop cancels the timer', () {
      final h = Harness();
      // Double-start must not stack timers: a single stop() must leave no
      // pending timer behind (flutter_test fails the test on leaked timers).
      h.queue.start();
      h.queue.start();
      h.queue.stop();
      // stop() when already stopped is a no-op.
      h.queue.stop();
      expect(h.plugin.delivered, isEmpty);
    });
  });
}

class _ThrowingPlugin implements ForwardChannelPlugin {
  @override
  ForwardChannel get channel => ForwardChannel.sms;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<SmsSendResult> deliver(ForwardTask task) async =>
      throw StateError('boom');
}
