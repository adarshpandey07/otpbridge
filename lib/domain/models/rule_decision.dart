import 'package:equatable/equatable.dart';

import 'forward_rule.dart';

enum DecisionKind { forward, block, requireApproval, noMatch }

/// Output of the rule engine for one classified SMS.
class RuleDecision extends Equatable {
  const RuleDecision({
    required this.kind,
    this.rule,
    this.recipientIds = const [],
    this.reason,
  });

  final DecisionKind kind;
  final ForwardRule? rule;
  final List<String> recipientIds;

  /// Human-readable explanation shown in history/approval UI.
  final String? reason;

  const RuleDecision.noMatch()
      : this(kind: DecisionKind.noMatch, reason: 'No rule matched');

  @override
  List<Object?> get props => [kind, rule?.id, recipientIds, reason];
}
