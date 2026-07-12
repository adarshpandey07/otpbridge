import 'dart:async';

import 'package:otpbridge/domain/models/models.dart';
import 'package:otpbridge/domain/repositories/repositories.dart';
import 'package:otpbridge/domain/services/service_contracts.dart';

/// In-memory repository + service fakes shared across pipeline tests.

class InMemoryRulesRepository implements RulesRepository {
  final Map<String, ForwardRule> _m = {};
  @override
  Future<List<ForwardRule>> getAll() async {
    final l = _m.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return l;
  }

  @override
  Future<void> save(ForwardRule rule) async => _m[rule.id] = rule;
  @override
  Future<void> saveAll(List<ForwardRule> rules) async {
    for (final r in rules) {
      _m[r.id] = r;
    }
  }

  @override
  Future<void> remove(String id) async => _m.remove(id);
  @override
  Stream<List<ForwardRule>> watch() async* {
    yield await getAll();
  }
}

class InMemoryRecipientsRepository implements RecipientsRepository {
  final Map<String, Recipient> _m = {};
  final Map<String, RecipientGroup> _g = {};
  @override
  Future<List<Recipient>> getAll() async => _m.values.toList();
  @override
  Future<Recipient?> getById(String id) async => _m[id];
  @override
  Future<void> save(Recipient r) async => _m[r.id] = r;
  @override
  Future<void> remove(String id) async => _m.remove(id);
  @override
  Future<List<RecipientGroup>> getGroups() async => _g.values.toList();
  @override
  Future<void> saveGroup(RecipientGroup group) async => _g[group.id] = group;
  @override
  Future<void> removeGroup(String id) async => _g.remove(id);
  @override
  Stream<List<Recipient>> watch() async* {
    yield await getAll();
  }
}

class InMemoryHistoryRepository implements HistoryRepository {
  final List<HistoryEntry> entries = [];
  @override
  Future<List<HistoryEntry>> getAll({int? limit}) async {
    final l = entries.reversed.toList();
    return limit == null ? l : l.take(limit).toList();
  }

  @override
  Future<void> add(HistoryEntry e) async => entries.add(e);
  @override
  Future<void> update(HistoryEntry e) async {
    final i = entries.indexWhere((x) => x.id == e.id);
    if (i >= 0) entries[i] = e;
  }

  @override
  Future<void> clear() async => entries.clear();
  @override
  Stream<List<HistoryEntry>> watch() async* {
    yield await getAll();
  }
}

class InMemoryQueueRepository implements QueueRepository {
  final Map<String, ForwardTask> _m = {};
  final Set<String> _fingerprints = {};
  @override
  Future<List<ForwardTask>> getAll() async => _m.values.toList();
  @override
  Future<List<ForwardTask>> getPending(DateTime now) async => _m.values
      .where((t) =>
          !t.isTerminal &&
          (t.status == ForwardStatus.queued ||
              t.status == ForwardStatus.failed) &&
          (t.nextAttemptAt == null || !t.nextAttemptAt!.isAfter(now)))
      .toList();
  @override
  Future<void> save(ForwardTask t) async => _m[t.id] = t;
  @override
  Future<void> remove(String id) async => _m.remove(id);
  @override
  Future<bool> hasFingerprint(String f) async => _fingerprints.contains(f);
  @override
  Future<void> rememberFingerprint(String f) async => _fingerprints.add(f);
  @override
  Stream<List<ForwardTask>> watch() async* {
    yield await getAll();
  }
}

class InMemoryApprovalsRepository implements ApprovalsRepository {
  final Map<String, PendingApproval> m = {};
  @override
  Future<List<PendingApproval>> getAll() async => m.values.toList();
  @override
  Future<void> add(PendingApproval a) async => m[a.id] = a;
  @override
  Future<void> remove(String id) async => m.remove(id);
  @override
  Stream<List<PendingApproval>> watch() async* {
    yield await getAll();
  }
}

class InMemorySettingsRepository implements SettingsRepository {
  AppSettings _s;
  InMemorySettingsRepository([AppSettings? s])
      : _s = s ?? const AppSettings(listeningEnabled: true);
  @override
  Future<AppSettings> get() async => _s;
  @override
  Future<void> save(AppSettings s) async => _s = s;
  @override
  Stream<AppSettings> watch() async* {
    yield _s;
  }
}

class InMemorySubscriptionRepository implements SubscriptionRepository {
  SubscriptionState _s;
  InMemorySubscriptionRepository([SubscriptionState? s])
      : _s = s ?? SubscriptionState(periodStart: DateTime(2026, 7));
  @override
  Future<SubscriptionState> get() async => _s;
  @override
  Future<void> save(SubscriptionState s) async => _s = s;
  @override
  Stream<SubscriptionState> watch() async* {
    yield _s;
  }
}

/// A classifier that returns whatever you hand it.
class StubClassificationEngine implements ClassificationEngine {
  StubClassificationEngine(this._canned);
  final SmsClassification Function(IncomingSms) _canned;
  @override
  Future<SmsClassification> classify(IncomingSms sms) async => _canned(sms);
  @override
  SmsClassification classifySync(IncomingSms sms) => _canned(sms);
}
