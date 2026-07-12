import 'package:equatable/equatable.dart';

/// Delivery channel for a forwarded OTP.
/// SMS ships in v1; the others are registered channel plugins that can be
/// enabled as integrations land (see ForwardChannelPlugin).
enum ForwardChannel { sms, whatsapp, telegram, email, push }

extension ForwardChannelX on ForwardChannel {
  String get label => switch (this) {
        ForwardChannel.sms => 'SMS',
        ForwardChannel.whatsapp => 'WhatsApp',
        ForwardChannel.telegram => 'Telegram',
        ForwardChannel.email => 'Email',
        ForwardChannel.push => 'Push',
      };
}

class Recipient extends Equatable {
  const Recipient({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.preferredChannel = ForwardChannel.sms,
    this.groupIds = const [],
    this.createdAt,
  });

  final String id;
  final String name;
  final String phone;
  final String? email;
  final ForwardChannel preferredChannel;
  final List<String> groupIds;
  final DateTime? createdAt;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Recipient copyWith({
    String? name,
    String? phone,
    String? email,
    ForwardChannel? preferredChannel,
    List<String>? groupIds,
  }) =>
      Recipient(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        preferredChannel: preferredChannel ?? this.preferredChannel,
        groupIds: groupIds ?? this.groupIds,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'preferredChannel': preferredChannel.name,
        'groupIds': groupIds,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory Recipient.fromJson(Map<String, dynamic> json) => Recipient(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        email: json['email'] as String?,
        preferredChannel: ForwardChannel.values.firstWhere(
          (c) => c.name == json['preferredChannel'],
          orElse: () => ForwardChannel.sms,
        ),
        groupIds: (json['groupIds'] as List?)?.cast<String>() ?? const [],
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      );

  @override
  List<Object?> get props => [id, name, phone, email, preferredChannel, groupIds];
}

class RecipientGroup extends Equatable {
  const RecipientGroup({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory RecipientGroup.fromJson(Map<String, dynamic> json) =>
      RecipientGroup(id: json['id'] as String, name: json['name'] as String? ?? '');

  @override
  List<Object?> get props => [id, name];
}
