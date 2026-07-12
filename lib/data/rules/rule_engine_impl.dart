import 'package:otpbridge/domain/models/models.dart';
import 'package:otpbridge/domain/services/service_contracts.dart';

import 'schedule_evaluator.dart';

/// Default rule-matching engine.
///
/// Evaluates rules top to bottom (callers pass rules already sorted by
/// `sortOrder`); the first matching enabled rule wins. Pure, deterministic,
/// never throws — a rule that fails to evaluate is skipped.
class DefaultRuleEngine implements RuleEngine {
  DefaultRuleEngine({ScheduleEvaluator? scheduleEvaluator})
      : _schedules = scheduleEvaluator ?? const ScheduleEvaluator();

  final ScheduleEvaluator _schedules;

  @override
  RuleDecision evaluate({
    required SmsClassification classification,
    required List<ForwardRule> rules,
    required AppSettings settings,
    required DateTime now,
  }) {
    for (final rule in rules) {
      try {
        if (!rule.enabled) continue;
        if (!_matches(rule, classification, now)) continue;
        return _decide(rule, classification, settings);
      } catch (_) {
        // Never throw: skip a rule that cannot be evaluated.
        continue;
      }
    }
    return const RuleDecision.noMatch();
  }

  /// A rule matches when ALL of its non-empty conditions match.
  bool _matches(ForwardRule rule, SmsClassification c, DateTime now) {
    if (rule.categories.isNotEmpty && !rule.categories.contains(c.category)) {
      return false;
    }
    if (rule.brands.isNotEmpty && !_matchesBrand(rule.brands, c.brand)) {
      return false;
    }
    if (rule.senders.isNotEmpty && !_matchesSender(rule.senders, c.sms.sender)) {
      return false;
    }
    if (!_hasAllKeywords(rule.keywords, c.sms.body)) return false;
    return _schedules.isActive(rule.schedule, now);
  }

  /// Case-insensitive equality against any listed brand.
  bool _matchesBrand(List<String> brands, String? brand) {
    if (brand == null || brand.trim().isEmpty) return false;
    final needle = brand.trim().toLowerCase();
    return brands.any((b) => b.trim().toLowerCase() == needle);
  }

  /// Case-insensitive substring/prefix match against the SMS sender.
  bool _matchesSender(List<String> senders, String sender) {
    final haystack = sender.toLowerCase();
    return senders.any((s) {
      final needle = s.trim().toLowerCase();
      return needle.isNotEmpty && haystack.contains(needle);
    });
  }

  /// Every non-blank keyword must appear (case-insensitively) in the body.
  bool _hasAllKeywords(List<String> keywords, String body) {
    if (keywords.isEmpty) return true;
    final haystack = body.toLowerCase();
    return keywords
        .where((k) => k.trim().isNotEmpty)
        .every((k) => haystack.contains(k.trim().toLowerCase()));
  }

  RuleDecision _decide(
    ForwardRule rule,
    SmsClassification c,
    AppSettings settings,
  ) {
    switch (rule.action) {
      case RuleAction.block:
        return RuleDecision(
          kind: DecisionKind.block,
          rule: rule,
          recipientIds: rule.recipientIds,
          reason: 'Blocked by rule "${rule.name}"',
        );
      case RuleAction.requireApproval:
        return RuleDecision(
          kind: DecisionKind.requireApproval,
          rule: rule,
          recipientIds: rule.recipientIds,
          reason: 'Rule "${rule.name}" requires approval',
        );
      case RuleAction.forward:
        final escalation = _escalationReason(rule, c, settings);
        if (escalation != null) {
          return RuleDecision(
            kind: DecisionKind.requireApproval,
            rule: rule,
            recipientIds: rule.recipientIds,
            reason: escalation,
          );
        }
        return RuleDecision(
          kind: DecisionKind.forward,
          rule: rule,
          recipientIds: rule.recipientIds,
          reason: 'Matched rule "${rule.name}"',
        );
    }
  }

  /// Security escalations that turn a forward into requireApproval.
  /// Precedence: rule amount cap → global banking cap → high-risk approval.
  String? _escalationReason(
    ForwardRule rule,
    SmsClassification c,
    AppSettings settings,
  ) {
    final amount = c.amount;

    // 1. Rule-level amount cap.
    final maxAmount = rule.maxAmount;
    if (maxAmount != null && amount != null && amount > maxAmount) {
      return "Amount ₹${_rupees(amount)} above this rule's "
          '₹${_rupees(maxAmount)} limit';
    }

    // 2. Global banking auto-forward cap for financial categories.
    if (c.category.isFinancial &&
        amount != null &&
        amount > settings.bankingAutoForwardCap) {
      return 'Amount ₹${_rupees(amount)} above your '
          '₹${_rupees(settings.bankingAutoForwardCap)} auto-forward cap';
    }

    // 3. High-risk categories require approval unless the rule explicitly
    //    names the category (respect the user's explicit intent).
    if (settings.highRiskRequiresApproval &&
        c.category.risk == RiskTier.high &&
        !rule.categories.contains(c.category)) {
      return 'High-risk OTP requires approval';
    }

    return null;
  }

  String _rupees(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
}
