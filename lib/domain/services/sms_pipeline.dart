import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../repositories/repositories.dart';
import 'notification_service.dart';
import 'service_contracts.dart';

/// Orchestrates the full flow for one incoming SMS:
///
/// SMS → classify → rule match → security validation → recipient resolution
/// → offline-queue enqueue → forward → history → notify.
///
/// This is the single entry point the platform layer calls for each message.
class SmsPipeline {
  SmsPipeline({
    required ClassificationEngine classifier,
    required RuleEngine ruleEngine,
    required ForwardingQueue queue,
    required RulesRepository rulesRepo,
    required RecipientsRepository recipientsRepo,
    required HistoryRepository historyRepo,
    required ApprovalsRepository approvalsRepo,
    required SettingsRepository settingsRepo,
    required SubscriptionRepository subscriptionRepo,
    required QueueRepository queueRepo,
    required NotificationService notifications,
    Uuid uuid = const Uuid(),
    DateTime Function() clock = DateTime.now,
  })  : _classifier = classifier,
        _ruleEngine = ruleEngine,
        _queue = queue,
        _rulesRepo = rulesRepo,
        _recipientsRepo = recipientsRepo,
        _historyRepo = historyRepo,
        _approvalsRepo = approvalsRepo,
        _settingsRepo = settingsRepo,
        _subscriptionRepo = subscriptionRepo,
        _queueRepo = queueRepo,
        _notifications = notifications,
        _uuid = uuid,
        _clock = clock;

  final ClassificationEngine _classifier;
  final RuleEngine _ruleEngine;
  final ForwardingQueue _queue;
  final RulesRepository _rulesRepo;
  final RecipientsRepository _recipientsRepo;
  final HistoryRepository _historyRepo;
  final ApprovalsRepository _approvalsRepo;
  final SettingsRepository _settingsRepo;
  final SubscriptionRepository _subscriptionRepo;
  final QueueRepository _queueRepo;
  final NotificationService _notifications;
  final Uuid _uuid;
  final DateTime Function() _clock;

  /// Process one incoming SMS end to end. Returns the recorded history entry,
  /// or null when the message carried no OTP and was ignored.
  Future<HistoryEntry?> process(IncomingSms sms) async {
    final settings = await _settingsRepo.get();
    if (!settings.listeningEnabled) return null;

    // 1. Classify.
    final classification = await _classifier.classify(sms);

    // Not an OTP message → ignore silently, don't pollute history.
    if (!classification.hasOtp) return null;

    // 2. Replay / duplicate protection.
    if (await _queueRepo.hasFingerprint(sms.fingerprint)) {
      return _record(classification, OtpOutcome.ignored,
          detail: 'Duplicate message ignored');
    }
    await _queueRepo.rememberFingerprint(sms.fingerprint);

    // 3. Rule matching + security validation.
    final rules = await _rulesRepo.getAll();
    final decision = _ruleEngine.evaluate(
      classification: classification,
      rules: rules,
      settings: settings,
      now: _clock(),
    );

    switch (decision.kind) {
      case DecisionKind.noMatch:
        return _record(classification, OtpOutcome.ignored,
            detail: decision.reason);

      case DecisionKind.block:
        final entry = await _record(classification, OtpOutcome.blocked,
            rule: decision.rule, detail: decision.reason);
        await _notifications.showBlocked(entry);
        return entry;

      case DecisionKind.requireApproval:
        return _requireApproval(classification, decision, settings);

      case DecisionKind.forward:
        return _forward(classification, decision);
    }
  }

  Future<HistoryEntry> _forward(
    SmsClassification classification,
    RuleDecision decision,
  ) async {
    // 4. Subscription gate: free tier has a monthly forward cap.
    final sub = await _subscriptionRepo.get();
    if (!sub.hasForwardsLeft) {
      final entry = await _record(classification, OtpOutcome.blocked,
          rule: decision.rule,
          detail: 'Monthly free forward limit reached — upgrade to continue');
      await _notifications.showSubscriptionExpired();
      return entry;
    }

    // 5. Resolve recipients (dedup across direct + group members handled by engine).
    final recipients = await _resolveRecipients(decision.recipientIds);
    if (recipients.isEmpty) {
      return _record(classification, OtpOutcome.failed,
          rule: decision.rule,
          detail: 'Rule matched but no valid recipient configured');
    }

    // 6. Enqueue (offline-first) and attempt immediate processing.
    final tasks = await _queue.enqueueForDecision(
      classification: classification,
      decision: decision,
      recipients: recipients,
    );

    await _subscriptionRepo.save(sub.copyWith(forwardsUsed: sub.forwardsUsed + 1));

    final entry = await _record(
      classification,
      OtpOutcome.queued,
      rule: decision.rule,
      recipients: recipients,
      detail: 'Queued to ${recipients.length} recipient'
          '${recipients.length == 1 ? '' : 's'}',
    );
    for (final task in tasks) {
      await _notifications.showQueued(task);
    }

    // Bump the rule's trigger counter.
    if (decision.rule != null) {
      await _rulesRepo.save(decision.rule!
          .copyWith(timesTriggered: decision.rule!.timesTriggered + 1));
    }

    // Try to flush immediately; background worker handles the rest.
    await _queue.processDue();
    return entry;
  }

  Future<HistoryEntry> _requireApproval(
    SmsClassification classification,
    RuleDecision decision,
    AppSettings settings,
  ) async {
    final now = _clock();
    final approval = PendingApproval(
      id: _uuid.v4(),
      classification: classification,
      createdAt: now,
      expiresAt: now.add(Duration(minutes: settings.approvalTtlMinutes)),
      ruleId: decision.rule?.id,
      ruleName: decision.rule?.name,
      recipientIds: decision.recipientIds,
      reason: decision.reason,
    );
    await _approvalsRepo.add(approval);
    await _notifications.showApprovalNeeded(approval);
    return _record(classification, OtpOutcome.pendingApproval,
        rule: decision.rule, detail: decision.reason);
  }

  /// Called from the approval UI when the user approves a pending OTP.
  Future<void> approve(PendingApproval approval) async {
    final recipients = await _resolveRecipients(approval.recipientIds);
    final decision = RuleDecision(
      kind: DecisionKind.forward,
      recipientIds: approval.recipientIds,
      reason: 'Manually approved',
    );
    final tasks = await _queue.enqueueForDecision(
      classification: approval.classification,
      decision: decision,
      recipients: recipients,
    );
    await _approvalsRepo.remove(approval.id);
    await _record(approval.classification, OtpOutcome.approved,
        detail: 'Approved · queued to ${recipients.length} recipient(s)');
    for (final task in tasks) {
      await _notifications.showQueued(task);
    }
    await _queue.processDue();
  }

  Future<void> reject(PendingApproval approval) async {
    await _approvalsRepo.remove(approval.id);
    await _record(approval.classification, OtpOutcome.rejected,
        detail: 'Rejected by user');
  }

  Future<List<Recipient>> _resolveRecipients(List<String> ids) async {
    final all = await _recipientsRepo.getAll();
    final byId = {for (final r in all) r.id: r};
    return ids.map((id) => byId[id]).whereType<Recipient>().toList();
  }

  Future<HistoryEntry> _record(
    SmsClassification classification,
    OtpOutcome outcome, {
    ForwardRule? rule,
    List<Recipient> recipients = const [],
    String? detail,
  }) async {
    final entry = HistoryEntry(
      id: _uuid.v4(),
      at: _clock(),
      classification: classification,
      outcome: outcome,
      ruleId: rule?.id,
      ruleName: rule?.name,
      recipientNames: recipients.map((r) => r.name).toList(),
      detail: detail,
    );
    await _historyRepo.add(entry);
    return entry;
  }
}
