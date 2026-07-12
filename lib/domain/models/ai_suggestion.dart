import 'package:equatable/equatable.dart';

import 'forward_rule.dart';

/// A proactive automation suggestion derived from usage patterns
/// ("You approved 4 Amazon OTPs for Rahul this week — automate it?").
class AiSuggestion extends Equatable {
  const AiSuggestion({
    required this.id,
    required this.title,
    required this.body,
    required this.proposedRule,
    required this.createdAt,
    this.dismissed = false,
  });

  final String id;
  final String title;
  final String body;
  final ForwardRule proposedRule;
  final DateTime createdAt;
  final bool dismissed;

  AiSuggestion copyWith({bool? dismissed}) => AiSuggestion(
        id: id,
        title: title,
        body: body,
        proposedRule: proposedRule,
        createdAt: createdAt,
        dismissed: dismissed ?? this.dismissed,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'proposedRule': proposedRule.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'dismissed': dismissed,
      };

  factory AiSuggestion.fromJson(Map<String, dynamic> json) => AiSuggestion(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        proposedRule: ForwardRule.fromJson(
            Map<String, dynamic>.from(json['proposedRule'] as Map)),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        dismissed: json['dismissed'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [id, title, createdAt, dismissed];
}
