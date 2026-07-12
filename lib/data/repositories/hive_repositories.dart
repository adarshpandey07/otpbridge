import 'dart:async';

import 'package:hive/hive.dart';

import '../../core/storage/local_store.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';

/// Hive-backed implementations of every repository contract.
/// Values are stored as JSON maps inside AES-encrypted boxes.

mixin _Watchable<T> {
  Stream<List<T>> watchBox(Box<Map> box, List<T> Function() read) async* {
    yield read();
    yield* box.watch().map((_) => read());
  }
}

class HiveRulesRepository with _Watchable<ForwardRule> implements RulesRepository {
  HiveRulesRepository(this._store);
  final LocalStore _store;

  Box<Map> get _box => _store.box(LocalStore.rulesBox);

  List<ForwardRule> _read() {
    final rules = _store.readAll(LocalStore.rulesBox, ForwardRule.fromJson);
    rules.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return rules;
  }

  @override
  Future<List<ForwardRule>> getAll() async => _read();

  @override
  Future<void> save(ForwardRule rule) => _store.put(LocalStore.rulesBox, rule.id, rule.toJson());

  @override
  Future<void> saveAll(List<ForwardRule> rules) async {
    for (final rule in rules) {
      await save(rule);
    }
  }

  @override
  Future<void> remove(String id) => _store.delete(LocalStore.rulesBox, id);

  @override
  Stream<List<ForwardRule>> watch() => watchBox(_box, _read);
}

class HiveRecipientsRepository
    with _Watchable<Recipient>
    implements RecipientsRepository {
  HiveRecipientsRepository(this._store);
  final LocalStore _store;

  Box<Map> get _box => _store.box(LocalStore.recipientsBox);

  List<Recipient> _read() {
    final all = _store.readAll(LocalStore.recipientsBox, Recipient.fromJson);
    all.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return all;
  }

  @override
  Future<List<Recipient>> getAll() async => _read();

  @override
  Future<Recipient?> getById(String id) async {
    final raw = _box.get(id);
    if (raw == null) return null;
    return Recipient.fromJson(Map<String, dynamic>.from(raw));
  }

  @override
  Future<void> save(Recipient recipient) =>
      _store.put(LocalStore.recipientsBox, recipient.id, recipient.toJson());

  @override
  Future<void> remove(String id) => _store.delete(LocalStore.recipientsBox, id);

  @override
  Future<List<RecipientGroup>> getGroups() async =>
      _store.readAll(LocalStore.groupsBox, RecipientGroup.fromJson);

  @override
  Future<void> saveGroup(RecipientGroup group) =>
      _store.put(LocalStore.groupsBox, group.id, group.toJson());

  @override
  Future<void> removeGroup(String id) => _store.delete(LocalStore.groupsBox, id);

  @override
  Stream<List<Recipient>> watch() => watchBox(_box, _read);
}

class HiveHistoryRepository
    with _Watchable<HistoryEntry>
    implements HistoryRepository {
  HiveHistoryRepository(this._store);
  final LocalStore _store;

  /// Keep history bounded so the box can't grow forever.
  static const int maxEntries = 2000;

  Box<Map> get _box => _store.box(LocalStore.historyBox);

  List<HistoryEntry> _read({int? limit}) {
    final all = _store.readAll(LocalStore.historyBox, HistoryEntry.fromJson);
    all.sort((a, b) => b.at.compareTo(a.at));
    if (limit != null && all.length > limit) return all.sublist(0, limit);
    return all;
  }

  @override
  Future<List<HistoryEntry>> getAll({int? limit}) async => _read(limit: limit);

  @override
  Future<void> add(HistoryEntry entry) async {
    await _store.put(LocalStore.historyBox, entry.id, entry.toJson());
    if (_box.length > maxEntries) {
      final all = _read();
      for (final old in all.skip(maxEntries)) {
        await _store.delete(LocalStore.historyBox, old.id);
      }
    }
  }

  @override
  Future<void> update(HistoryEntry entry) =>
      _store.put(LocalStore.historyBox, entry.id, entry.toJson());

  @override
  Future<void> clear() => _box.clear();

  @override
  Stream<List<HistoryEntry>> watch() => watchBox(_box, _read);
}

class HiveQueueRepository
    with _Watchable<ForwardTask>
    implements QueueRepository {
  HiveQueueRepository(this._store);
  final LocalStore _store;

  static const String _fingerprintKey = 'fingerprints';
  static const int _maxFingerprints = 500;

  Box<Map> get _box => _store.box(LocalStore.queueBox);
  Box<Map> get _meta => _store.box(LocalStore.metaBox);

  List<ForwardTask> _read() {
    final all = _store.readAll(LocalStore.queueBox, ForwardTask.fromJson);
    all.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return all;
  }

  @override
  Future<List<ForwardTask>> getAll() async => _read();

  @override
  Future<List<ForwardTask>> getPending(DateTime now) async => _read()
      .where((t) =>
          !t.isTerminal &&
          (t.status == ForwardStatus.queued || t.status == ForwardStatus.failed) &&
          (t.nextAttemptAt == null || !t.nextAttemptAt!.isAfter(now)))
      .toList();

  @override
  Future<void> save(ForwardTask task) =>
      _store.put(LocalStore.queueBox, task.id, task.toJson());

  @override
  Future<void> remove(String id) => _store.delete(LocalStore.queueBox, id);

  @override
  Future<bool> hasFingerprint(String fingerprint) async {
    final raw = _meta.get(_fingerprintKey);
    if (raw == null) return false;
    final list = (raw['list'] as List?)?.cast<String>() ?? const [];
    return list.contains(fingerprint);
  }

  @override
  Future<void> rememberFingerprint(String fingerprint) async {
    final raw = _meta.get(_fingerprintKey);
    final list = ((raw?['list'] as List?)?.cast<String>() ?? const <String>[])
        .toList();
    list.add(fingerprint);
    while (list.length > _maxFingerprints) {
      list.removeAt(0);
    }
    await _meta.put(_fingerprintKey, {'list': list});
  }

  @override
  Stream<List<ForwardTask>> watch() => watchBox(_box, _read);
}

class HiveApprovalsRepository
    with _Watchable<PendingApproval>
    implements ApprovalsRepository {
  HiveApprovalsRepository(this._store);
  final LocalStore _store;

  Box<Map> get _box => _store.box(LocalStore.approvalsBox);

  List<PendingApproval> _read() {
    final all =
        _store.readAll(LocalStore.approvalsBox, PendingApproval.fromJson);
    all.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    return all;
  }

  @override
  Future<List<PendingApproval>> getAll() async => _read();

  @override
  Future<void> add(PendingApproval approval) =>
      _store.put(LocalStore.approvalsBox, approval.id, approval.toJson());

  @override
  Future<void> remove(String id) => _store.delete(LocalStore.approvalsBox, id);

  @override
  Stream<List<PendingApproval>> watch() => watchBox(_box, _read);
}

class HiveSettingsRepository implements SettingsRepository {
  HiveSettingsRepository(this._store);
  final LocalStore _store;

  static const String _key = 'app';

  Box<Map> get _box => _store.box(LocalStore.settingsBox);

  AppSettings _read() {
    final raw = _box.get(_key);
    if (raw == null) return const AppSettings();
    return AppSettings.fromJson(Map<String, dynamic>.from(raw));
  }

  @override
  Future<AppSettings> get() async => _read();

  @override
  Future<void> save(AppSettings settings) =>
      _box.put(_key, settings.toJson());

  @override
  Stream<AppSettings> watch() async* {
    yield _read();
    yield* _box.watch().map((_) => _read());
  }
}

class HiveSubscriptionRepository implements SubscriptionRepository {
  HiveSubscriptionRepository(this._store);
  final LocalStore _store;

  static const String _key = 'subscription';

  Box<Map> get _box => _store.box(LocalStore.settingsBox);

  SubscriptionState _read() {
    final raw = _box.get(_key);
    if (raw == null) {
      final now = DateTime.now();
      return SubscriptionState(periodStart: DateTime(now.year, now.month));
    }
    var state = SubscriptionState.fromJson(Map<String, dynamic>.from(raw));
    // Roll the usage period on month boundaries.
    final now = DateTime.now();
    final currentPeriod = DateTime(now.year, now.month);
    if (state.periodStart.isBefore(currentPeriod)) {
      state = state.copyWith(periodStart: currentPeriod, forwardsUsed: 0);
      _box.put(_key, state.toJson());
    }
    return state;
  }

  @override
  Future<SubscriptionState> get() async => _read();

  @override
  Future<void> save(SubscriptionState state) => _box.put(_key, state.toJson());

  @override
  Stream<SubscriptionState> watch() async* {
    yield _read();
    yield* _box.watch().map((_) => _read());
  }
}

class HiveSuggestionsRepository
    with _Watchable<AiSuggestion>
    implements SuggestionsRepository {
  HiveSuggestionsRepository(this._store);
  final LocalStore _store;

  Box<Map> get _box => _store.box(LocalStore.suggestionsBox);

  List<AiSuggestion> _read() {
    final all =
        _store.readAll(LocalStore.suggestionsBox, AiSuggestion.fromJson);
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  @override
  Future<List<AiSuggestion>> getAll() async => _read();

  @override
  Future<void> save(AiSuggestion suggestion) =>
      _store.put(LocalStore.suggestionsBox, suggestion.id, suggestion.toJson());

  @override
  Future<void> remove(String id) =>
      _store.delete(LocalStore.suggestionsBox, id);

  @override
  Stream<List<AiSuggestion>> watch() => watchBox(_box, _read);
}
