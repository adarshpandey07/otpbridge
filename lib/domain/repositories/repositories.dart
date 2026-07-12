import '../models/models.dart';

/// All repository contracts. Implementations live in lib/data/repositories.
/// Everything is local-first; a future RemoteSyncService can mirror these
/// stores to a backend without touching feature code.

abstract interface class RulesRepository {
  Future<List<ForwardRule>> getAll(); // sorted by sortOrder
  Future<void> save(ForwardRule rule);
  Future<void> saveAll(List<ForwardRule> rules);
  Future<void> remove(String id);
  Stream<List<ForwardRule>> watch();
}

abstract interface class RecipientsRepository {
  Future<List<Recipient>> getAll();
  Future<Recipient?> getById(String id);
  Future<void> save(Recipient recipient);
  Future<void> remove(String id);
  Future<List<RecipientGroup>> getGroups();
  Future<void> saveGroup(RecipientGroup group);
  Future<void> removeGroup(String id);
  Stream<List<Recipient>> watch();
}

abstract interface class HistoryRepository {
  Future<List<HistoryEntry>> getAll({int? limit}); // newest first
  Future<void> add(HistoryEntry entry);
  Future<void> update(HistoryEntry entry);
  Future<void> clear();
  Stream<List<HistoryEntry>> watch();
}

abstract interface class QueueRepository {
  Future<List<ForwardTask>> getAll();
  Future<List<ForwardTask>> getPending(DateTime now);
  Future<void> save(ForwardTask task);
  Future<void> remove(String id);
  Future<bool> hasFingerprint(String fingerprint);
  Future<void> rememberFingerprint(String fingerprint);
  Stream<List<ForwardTask>> watch();
}

abstract interface class ApprovalsRepository {
  Future<List<PendingApproval>> getAll();
  Future<void> add(PendingApproval approval);
  Future<void> remove(String id);
  Stream<List<PendingApproval>> watch();
}

abstract interface class SettingsRepository {
  Future<AppSettings> get();
  Future<void> save(AppSettings settings);
  Stream<AppSettings> watch();
}

abstract interface class SubscriptionRepository {
  Future<SubscriptionState> get();
  Future<void> save(SubscriptionState state);
  Stream<SubscriptionState> watch();
}

abstract interface class SuggestionsRepository {
  Future<List<AiSuggestion>> getAll();
  Future<void> save(AiSuggestion suggestion);
  Future<void> remove(String id);
  Stream<List<AiSuggestion>> watch();
}
