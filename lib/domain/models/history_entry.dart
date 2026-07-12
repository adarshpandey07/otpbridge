import 'package:equatable/equatable.dart';

import 'sms_classification.dart';

/// Final outcome of an OTP's journey through the pipeline.
enum OtpOutcome {
  forwarded,
  queued,
  blocked,
  pendingApproval,
  approved,
  rejected,
  expired,
  ignored, // no rule matched, nothing to do
  failed,
}

extension OtpOutcomeX on OtpOutcome {
  String get label => switch (this) {
        OtpOutcome.forwarded => 'Forwarded',
        OtpOutcome.queued => 'Queued',
        OtpOutcome.blocked => 'Blocked',
        OtpOutcome.pendingApproval => 'Needs approval',
        OtpOutcome.approved => 'Approved',
        OtpOutcome.rejected => 'Rejected',
        OtpOutcome.expired => 'Expired',
        OtpOutcome.ignored => 'No rule matched',
        OtpOutcome.failed => 'Failed',
      };
}

class HistoryEntry extends Equatable {
  const HistoryEntry({
    required this.id,
    required this.at,
    required this.classification,
    required this.outcome,
    this.ruleId,
    this.ruleName,
    this.recipientNames = const [],
    this.detail,
  });

  final String id;
  final DateTime at;
  final SmsClassification classification;
  final OtpOutcome outcome;
  final String? ruleId;
  final String? ruleName;
  final List<String> recipientNames;
  final String? detail;

  HistoryEntry copyWith({OtpOutcome? outcome, String? detail}) => HistoryEntry(
        id: id,
        at: at,
        classification: classification,
        outcome: outcome ?? this.outcome,
        ruleId: ruleId,
        ruleName: ruleName,
        recipientNames: recipientNames,
        detail: detail ?? this.detail,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': at.toIso8601String(),
        'classification': classification.toJson(),
        'outcome': outcome.name,
        'ruleId': ruleId,
        'ruleName': ruleName,
        'recipientNames': recipientNames,
        'detail': detail,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        id: json['id'] as String,
        at: DateTime.tryParse(json['at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        classification: SmsClassification.fromJson(
            Map<String, dynamic>.from(json['classification'] as Map)),
        outcome: OtpOutcome.values.firstWhere(
          (o) => o.name == json['outcome'],
          orElse: () => OtpOutcome.ignored,
        ),
        ruleId: json['ruleId'] as String?,
        ruleName: json['ruleName'] as String?,
        recipientNames:
            (json['recipientNames'] as List?)?.cast<String>() ?? const [],
        detail: json['detail'] as String?,
      );

  @override
  List<Object?> get props => [id, at, outcome, ruleId, recipientNames];
}
