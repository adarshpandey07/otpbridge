import 'package:equatable/equatable.dart';

import 'otp_category.dart';

/// A brand/app the user actually receives SMS from, discovered by scanning
/// the inbox. Powers "dynamic service detection" in the rule wizard and the
/// proactive suggestion engine — we only ever show services that really
/// message this user.
class DetectedService extends Equatable {
  const DetectedService({
    required this.brand,
    required this.category,
    required this.sampleSender,
    required this.messageCount,
    required this.lastSeen,
  });

  final String brand;
  final OtpCategory category;
  final String sampleSender;
  final int messageCount;
  final DateTime lastSeen;

  CategoryGroup get group => category.group;

  DetectedService merge(DetectedService other) => DetectedService(
        brand: brand,
        category: category,
        sampleSender: sampleSender,
        messageCount: messageCount + other.messageCount,
        lastSeen: lastSeen.isAfter(other.lastSeen) ? lastSeen : other.lastSeen,
      );

  @override
  List<Object?> get props => [brand, category, sampleSender];
}
