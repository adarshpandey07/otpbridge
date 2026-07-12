import '../models/incoming_sms.dart';

/// Result of a low-level send attempt over the SMS radio.
class SmsSendResult {
  const SmsSendResult({required this.success, this.error});
  final bool success;
  final String? error;

  const SmsSendResult.ok() : this(success: true);
  const SmsSendResult.fail(String reason) : this(success: false, error: reason);
}

/// Platform capabilities differ sharply between Android and iOS.
/// The app queries this before offering SMS-reading features.
class PlatformCapabilities {
  const PlatformCapabilities({
    required this.canReadSms,
    required this.canSendSms,
    required this.canRunBackgroundService,
  });

  final bool canReadSms;
  final bool canSendSms;
  final bool canRunBackgroundService;

  /// iOS: companion mode — manage rules/recipients/history, no auto-reading.
  const PlatformCapabilities.companion()
      : this(
          canReadSms: false,
          canSendSms: false,
          canRunBackgroundService: false,
        );
}

/// Abstraction over the native SMS layer. Android provides a full
/// implementation; iOS/tests provide a no-op companion implementation.
abstract interface class SmsGateway {
  Future<PlatformCapabilities> capabilities();

  /// Whether the app currently holds the runtime permissions it needs.
  Future<bool> hasPermissions();
  Future<bool> requestPermissions();

  /// Incoming messages surfaced by the native receiver.
  Stream<IncomingSms> get incoming;

  /// Start/stop the foreground listening service.
  Future<void> startListening();
  Future<void> stopListening();
  Future<bool> isListening();

  /// Read recent messages from the device SMS inbox (newest first). Used for
  /// dynamic service detection — figuring out which brands/apps actually send
  /// this user messages. Returns an empty list where unsupported.
  Future<List<IncomingSms>> readInbox({int limit = 500});

  /// Send an SMS via the device radio.
  Future<SmsSendResult> sendSms({required String to, required String body});
}

/// Companion / fallback gateway used on iOS and in tests.
class CompanionSmsGateway implements SmsGateway {
  @override
  Future<PlatformCapabilities> capabilities() async =>
      const PlatformCapabilities.companion();

  @override
  Future<bool> hasPermissions() async => false;

  @override
  Future<bool> requestPermissions() async => false;

  @override
  Stream<IncomingSms> get incoming => const Stream.empty();

  @override
  Future<void> startListening() async {}

  @override
  Future<void> stopListening() async {}

  @override
  Future<bool> isListening() async => false;

  @override
  Future<List<IncomingSms>> readInbox({int limit = 500}) async => const [];

  @override
  Future<SmsSendResult> sendSms({required String to, required String body}) async =>
      const SmsSendResult.fail('SMS sending is not available on this platform');
}
