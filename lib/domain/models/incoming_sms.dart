import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';

/// A raw SMS as delivered by the platform layer.
class IncomingSms extends Equatable {
  const IncomingSms({
    required this.id,
    required this.sender,
    required this.body,
    required this.receivedAt,
    this.simSlot,
  });

  final String id;
  final String sender;
  final String body;
  final DateTime receivedAt;
  final int? simSlot;

  /// Stable fingerprint used for replay/duplicate protection.
  /// Same sender + body within the same minute → same hash.
  String get fingerprint {
    final bucket = receivedAt.millisecondsSinceEpoch ~/ 60000;
    return sha256.convert(utf8.encode('$sender|$body|$bucket')).toString();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender': sender,
        'body': body,
        'receivedAt': receivedAt.toIso8601String(),
        'simSlot': simSlot,
      };

  factory IncomingSms.fromJson(Map<String, dynamic> json) => IncomingSms(
        id: json['id'] as String,
        sender: json['sender'] as String? ?? '',
        body: json['body'] as String? ?? '',
        receivedAt:
            DateTime.tryParse(json['receivedAt'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
        simSlot: json['simSlot'] as int?,
      );

  @override
  List<Object?> get props => [id, sender, body, receivedAt, simSlot];
}
