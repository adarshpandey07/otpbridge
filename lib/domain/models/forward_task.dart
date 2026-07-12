import 'package:equatable/equatable.dart';

import 'recipient.dart';
import 'sms_classification.dart';

enum ForwardStatus { queued, sending, sent, delivered, failed, cancelled }

/// One unit of work in the persistent offline queue:
/// deliver one OTP to one recipient over one channel.
class ForwardTask extends Equatable {
  const ForwardTask({
    required this.id,
    required this.classification,
    required this.recipientId,
    required this.recipientName,
    required this.destination,
    required this.channel,
    required this.createdAt,
    this.ruleId,
    this.status = ForwardStatus.queued,
    this.attempts = 0,
    this.nextAttemptAt,
    this.lastError,
    this.sentAt,
    this.deliveredAt,
  });

  static const int maxAttempts = 6;

  final String id;
  final SmsClassification classification;
  final String recipientId;
  final String recipientName;

  /// Phone number / email address depending on channel.
  final String destination;
  final ForwardChannel channel;
  final String? ruleId;
  final DateTime createdAt;
  final ForwardStatus status;
  final int attempts;
  final DateTime? nextAttemptAt;
  final String? lastError;
  final DateTime? sentAt;
  final DateTime? deliveredAt;

  bool get isTerminal =>
      status == ForwardStatus.delivered ||
      status == ForwardStatus.cancelled ||
      (status == ForwardStatus.failed && attempts >= maxAttempts);

  /// Exponential backoff: 5s, 20s, 80s, ~5min, ~21min, capped at 30min.
  Duration get backoff {
    final seconds = 5 * (1 << (2 * (attempts - 1).clamp(0, 5)));
    return Duration(seconds: seconds.clamp(5, 1800));
  }

  ForwardTask copyWith({
    ForwardStatus? status,
    int? attempts,
    DateTime? nextAttemptAt,
    String? lastError,
    DateTime? sentAt,
    DateTime? deliveredAt,
  }) =>
      ForwardTask(
        id: id,
        classification: classification,
        recipientId: recipientId,
        recipientName: recipientName,
        destination: destination,
        channel: channel,
        ruleId: ruleId,
        createdAt: createdAt,
        status: status ?? this.status,
        attempts: attempts ?? this.attempts,
        nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
        lastError: lastError ?? this.lastError,
        sentAt: sentAt ?? this.sentAt,
        deliveredAt: deliveredAt ?? this.deliveredAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'classification': classification.toJson(),
        'recipientId': recipientId,
        'recipientName': recipientName,
        'destination': destination,
        'channel': channel.name,
        'ruleId': ruleId,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        'attempts': attempts,
        'nextAttemptAt': nextAttemptAt?.toIso8601String(),
        'lastError': lastError,
        'sentAt': sentAt?.toIso8601String(),
        'deliveredAt': deliveredAt?.toIso8601String(),
      };

  factory ForwardTask.fromJson(Map<String, dynamic> json) => ForwardTask(
        id: json['id'] as String,
        classification: SmsClassification.fromJson(
            Map<String, dynamic>.from(json['classification'] as Map)),
        recipientId: json['recipientId'] as String? ?? '',
        recipientName: json['recipientName'] as String? ?? '',
        destination: json['destination'] as String? ?? '',
        channel: ForwardChannel.values.firstWhere(
          (c) => c.name == json['channel'],
          orElse: () => ForwardChannel.sms,
        ),
        ruleId: json['ruleId'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        status: ForwardStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => ForwardStatus.queued,
        ),
        attempts: json['attempts'] as int? ?? 0,
        nextAttemptAt:
            DateTime.tryParse(json['nextAttemptAt'] as String? ?? ''),
        lastError: json['lastError'] as String?,
        sentAt: DateTime.tryParse(json['sentAt'] as String? ?? ''),
        deliveredAt: DateTime.tryParse(json['deliveredAt'] as String? ?? ''),
      );

  @override
  List<Object?> get props =>
      [id, recipientId, destination, channel, status, attempts, nextAttemptAt];
}
