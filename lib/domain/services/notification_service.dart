import '../models/models.dart';

/// Rich notifications for OTP lifecycle events. Implemented over
/// flutter_local_notifications; a no-op impl is used in tests.
abstract interface class NotificationService {
  Future<void> init();

  Future<void> showForwarded(HistoryEntry entry, {bool maskOtp = true});
  Future<void> showQueued(ForwardTask task);
  Future<void> showRetrying(ForwardTask task);
  Future<void> showBlocked(HistoryEntry entry);
  Future<void> showApprovalNeeded(PendingApproval approval);
  Future<void> showSuggestion(AiSuggestion suggestion);
  Future<void> showSubscriptionExpired();

  /// Persistent notification shown while the listening service runs.
  Future<void> showListeningStatus({required bool active});
}

class NoopNotificationService implements NotificationService {
  @override
  Future<void> init() async {}
  @override
  Future<void> showForwarded(HistoryEntry entry, {bool maskOtp = true}) async {}
  @override
  Future<void> showQueued(ForwardTask task) async {}
  @override
  Future<void> showRetrying(ForwardTask task) async {}
  @override
  Future<void> showBlocked(HistoryEntry entry) async {}
  @override
  Future<void> showApprovalNeeded(PendingApproval approval) async {}
  @override
  Future<void> showSuggestion(AiSuggestion suggestion) async {}
  @override
  Future<void> showSubscriptionExpired() async {}
  @override
  Future<void> showListeningStatus({required bool active}) async {}
}
