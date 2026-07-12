import 'package:flutter_test/flutter_test.dart';
import 'package:otpbridge/data/classification/classification_engine_impl.dart';
import 'package:otpbridge/data/classification/service_detector.dart';
import 'package:otpbridge/domain/models/incoming_sms.dart';
import 'package:otpbridge/domain/services/sms_gateway.dart';

/// A gateway that returns a canned inbox.
class _FakeGateway implements SmsGateway {
  _FakeGateway(this._inbox);
  final List<IncomingSms> _inbox;

  @override
  Future<List<IncomingSms>> readInbox({int limit = 500}) async =>
      _inbox.take(limit).toList();

  @override
  Future<PlatformCapabilities> capabilities() async =>
      const PlatformCapabilities(
          canReadSms: true, canSendSms: true, canRunBackgroundService: true);
  @override
  Future<bool> hasPermissions() async => true;
  @override
  Future<bool> requestPermissions() async => true;
  @override
  Stream<IncomingSms> get incoming => const Stream.empty();
  @override
  Future<void> startListening() async {}
  @override
  Future<void> stopListening() async {}
  @override
  Future<bool> isListening() async => true;
  @override
  Future<SmsSendResult> sendSms(
          {required String to, required String body}) async =>
      const SmsSendResult.ok();
}

void main() {
  IncomingSms sms(String sender, String body, int minutesAgo) => IncomingSms(
        id: '$sender-$minutesAgo',
        sender: sender,
        body: body,
        receivedAt: DateTime(2026, 7, 12, 12).subtract(Duration(minutes: minutesAgo)),
      );

  test('groups inbox by brand, most-messaged first', () async {
    final gateway = _FakeGateway([
      sms('VM-AMAZON', 'Your Amazon OTP is 111111', 1),
      sms('VM-AMAZON', 'Your Amazon order shipped. OTP 222222', 30),
      sms('VK-AMAZON', 'Amazon delivery OTP 333333', 90),
      sms('JD-SWIGGY', 'Your Swiggy OTP is 4455', 10),
    ]);
    final detector = ServiceDetector(gateway, DefaultClassificationEngine());

    final services = await detector.detectAll();

    expect(services, isNotEmpty);
    // Amazon appears most often → first.
    expect(services.first.brand.toLowerCase(), contains('amazon'));
    expect(services.first.messageCount, greaterThanOrEqualTo(2));
    expect(
      services.any((s) => s.brand.toLowerCase().contains('swiggy')),
      isTrue,
    );
  });

  test('empty inbox yields no services', () async {
    final detector =
        ServiceDetector(_FakeGateway(const []), DefaultClassificationEngine());
    expect(await detector.detectAll(), isEmpty);
  });
}
