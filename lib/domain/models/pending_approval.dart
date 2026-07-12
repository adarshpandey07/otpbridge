import 'package:equatable/equatable.dart';

import 'sms_classification.dart';

/// A high-risk OTP awaiting the user's decision. Expires automatically.
class PendingApproval extends Equatable {
  const PendingApproval({
    required this.id,
    required this.classification,
    required this.createdAt,
    required this.expiresAt,
    this.ruleId,
    this.ruleName,
    this.recipientIds = const [],
    this.reason,
  });

  static const Duration defaultTtl = Duration(minutes: 5);

  final String id;
  final SmsClassification classification;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? ruleId;
  final String? ruleName;
  final List<String> recipientIds;

  /// Why approval is needed ("Amount above ₹5,000 cap", "High-risk category").
  final String? reason;

  bool isExpired(DateTime now) => now.isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'classification': classification.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'ruleId': ruleId,
        'ruleName': ruleName,
        'recipientIds': recipientIds,
        'reason': reason,
      };

  factory PendingApproval.fromJson(Map<String, dynamic> json) =>
      PendingApproval(
        id: json['id'] as String,
        classification: SmsClassification.fromJson(
            Map<String, dynamic>.from(json['classification'] as Map)),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        ruleId: json['ruleId'] as String?,
        ruleName: json['ruleName'] as String?,
        recipientIds:
            (json['recipientIds'] as List?)?.cast<String>() ?? const [],
        reason: json['reason'] as String?,
      );

  @override
  List<Object?> get props => [id, createdAt, expiresAt, ruleId, recipientIds];
}
