import '../models/models.dart';

/// Contract for the classification engine (implemented in data/classification).
/// Hybrid pipeline: local rules + regex → optional local ML → optional cloud.
abstract interface class ClassificationEngine {
  /// Classify a raw SMS into a structured result. Never throws; falls back
  /// to [OtpCategory.unknown] with low confidence on failure.
  Future<SmsClassification> classify(IncomingSms sms);

  /// Synchronous best-effort classification (rules + regex only), used where
  /// awaiting isn't possible.
  SmsClassification classifySync(IncomingSms sms);
}

/// Contract for the rule-matching engine (implemented in data/rules).
abstract interface class RuleEngine {
  /// Evaluate rules top-to-bottom against a classification and return the
  /// first matching decision, honoring schedules, amount caps, and the
  /// global banking cap / high-risk-approval settings.
  RuleDecision evaluate({
    required SmsClassification classification,
    required List<ForwardRule> rules,
    required AppSettings settings,
    required DateTime now,
  });
}

/// Contract for the offline forwarding queue (implemented in data/queue).
abstract interface class ForwardingQueue {
  /// Enqueue forwards for a decision. Applies duplicate protection and
  /// fans out to all resolved recipients/channels.
  Future<List<ForwardTask>> enqueueForDecision({
    required SmsClassification classification,
    required RuleDecision decision,
    required List<Recipient> recipients,
  });

  /// Enqueue an already-resolved single task (e.g. after manual approval).
  Future<void> enqueueTask(ForwardTask task);

  /// Process all due tasks once (called by the tick/background worker).
  Future<void> processDue();

  /// Kick a background/periodic processor.
  void start();
  void stop();
}
