import '../../domain/models/detected_service.dart';
import '../../domain/models/incoming_sms.dart';
import '../../domain/models/otp_category.dart';
import '../../domain/services/service_contracts.dart';
import '../../domain/services/sms_gateway.dart';

/// Scans the SMS inbox and groups messages into [DetectedService]s using the
/// classification engine. This is what lets the rule wizard show *only* the
/// brands/apps that actually message the user, and what feeds the proactive
/// suggestion engine.
class ServiceDetector {
  ServiceDetector(this._gateway, this._classifier);

  final SmsGateway _gateway;
  final ClassificationEngine _classifier;

  /// Detect all services from the inbox, most-messaged first.
  Future<List<DetectedService>> detectAll({int scan = 500}) async {
    final inbox = await _gateway.readInbox(limit: scan);
    return _group(inbox);
  }

  /// Detect only services whose category falls in [group].
  Future<List<DetectedService>> detectForGroup(
    CategoryGroup group, {
    int scan = 500,
  }) async {
    final all = await detectAll(scan: scan);
    return all.where((s) => s.group == group).toList();
  }

  List<DetectedService> _group(List<IncomingSms> inbox) {
    final byBrand = <String, DetectedService>{};
    for (final sms in inbox) {
      final c = _classifier.classifySync(sms);
      // Ignore obvious non-service noise (person-to-person texts have no
      // brand and land in unknown/personal).
      final brand = c.brand ?? _prettySender(sms.sender);
      if (brand.isEmpty) continue;
      if (c.category == OtpCategory.unknown && c.brand == null) {
        // Skip long numeric/person senders that aren't a recognizable service.
        if (_looksLikePhoneNumber(sms.sender)) continue;
      }
      final key = brand.toLowerCase();
      final entry = DetectedService(
        brand: brand,
        category: c.category,
        sampleSender: sms.sender,
        messageCount: 1,
        lastSeen: sms.receivedAt,
      );
      byBrand[key] =
          byBrand.containsKey(key) ? byBrand[key]!.merge(entry) : entry;
    }
    final list = byBrand.values.toList()
      ..sort((a, b) {
        final byCount = b.messageCount.compareTo(a.messageCount);
        return byCount != 0 ? byCount : b.lastSeen.compareTo(a.lastSeen);
      });
    return list;
  }

  static bool _looksLikePhoneNumber(String sender) {
    final digits = sender.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 10;
  }

  /// Turns a DLT header like "VM-AMAZON-S" into a readable fallback name.
  static String _prettySender(String sender) {
    final cleaned = sender.replaceAll(RegExp(r'^[A-Z]{2}-'), '').trim();
    final core = cleaned.split('-').first;
    if (core.isEmpty) return sender;
    return core[0].toUpperCase() + core.substring(1).toLowerCase();
  }
}
