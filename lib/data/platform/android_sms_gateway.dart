import 'dart:async';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/incoming_sms.dart';
import '../../domain/services/sms_gateway.dart';

/// Android implementation of [SmsGateway] over a platform MethodChannel
/// (commands) and EventChannel (incoming SMS stream).
///
/// Every channel call is guarded so that running on a platform without the
/// native handlers (tests, desktop, iOS) degrades to safe defaults instead
/// of throwing [MissingPluginException].
class AndroidSmsGateway implements SmsGateway {
  AndroidSmsGateway();

  static const MethodChannel _channel = MethodChannel('com.otpbridge/sms');
  static const EventChannel _events =
      EventChannel('com.otpbridge/sms_incoming');
  static const Uuid _uuid = Uuid();

  /// Runtime permissions the gateway needs. [Permission.sms] covers
  /// RECEIVE_SMS / READ_SMS / SEND_SMS (one Android permission group);
  /// [Permission.notification] covers POST_NOTIFICATIONS on Android 13+.
  static const List<Permission> _permissions = [
    Permission.sms,
    Permission.notification,
  ];

  Stream<IncomingSms>? _incoming;

  @override
  Future<PlatformCapabilities> capabilities() async {
    // Android always has the full stack; no need to round-trip the channel.
    return const PlatformCapabilities(
      canReadSms: true,
      canSendSms: true,
      canRunBackgroundService: true,
    );
  }

  @override
  Future<bool> hasPermissions() async {
    try {
      // SMS is the essential permission; notifications are requested too but
      // their denial must not block the pipeline.
      final status = await Permission.sms.status;
      return status.isGranted;
    } on Exception {
      // MissingPluginException / PlatformException on non-device runs.
      return false;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    try {
      final statuses = await _permissions.request();
      return statuses[Permission.sms]?.isGranted ?? false;
    } on Exception {
      return false;
    }
  }

  @override
  Stream<IncomingSms> get incoming => _incoming ??= _events
      .receiveBroadcastStream()
      .map<IncomingSms?>(_mapEvent)
      .where((sms) => sms != null)
      .cast<IncomingSms>()
      .handleError((Object _) {
        // Swallow channel errors (e.g. MissingPluginException in tests) so
        // downstream listeners never crash; the stream simply stays quiet.
      });

  @override
  Future<void> startListening() async {
    try {
      await _channel.invokeMethod<void>('startListening');
    } on PlatformException {
      // Native side rejected the call; nothing to do.
    } on MissingPluginException {
      // Not running on Android.
    }
  }

  @override
  Future<void> stopListening() async {
    try {
      await _channel.invokeMethod<void>('stopListening');
    } on PlatformException {
      // Ignore.
    } on MissingPluginException {
      // Not running on Android.
    }
  }

  @override
  Future<bool> isListening() async {
    try {
      return await _channel.invokeMethod<bool>('isListening') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<List<IncomingSms>> readInbox({int limit = 500}) async {
    try {
      final raw = await _channel
          .invokeMethod<List<dynamic>>('readInbox', {'limit': limit});
      if (raw == null) return const [];
      return raw
          .map(_mapEvent)
          .whereType<IncomingSms>()
          .toList(growable: false);
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  @override
  Future<SmsSendResult> sendSms({
    required String to,
    required String body,
  }) async {
    try {
      final ok = await _channel
          .invokeMethod<bool>('sendSms', {'to': to, 'body': body});
      return (ok ?? false)
          ? const SmsSendResult.ok()
          : const SmsSendResult.fail('The SMS could not be handed to the radio');
    } on PlatformException catch (e) {
      return SmsSendResult.fail(e.message ?? 'Platform error while sending');
    } on MissingPluginException {
      return const SmsSendResult.fail(
          'SMS sending is not available on this platform');
    }
  }

  /// Maps a raw platform event (`{sender, body, timestamp, simSlot}`) into
  /// an [IncomingSms]. Returns null for malformed events.
  static IncomingSms? _mapEvent(dynamic event) {
    if (event is! Map) return null;
    final sender = event['sender'] as String? ?? '';
    final body = event['body'] as String? ?? '';
    if (sender.isEmpty && body.isEmpty) return null;
    final millis = (event['timestamp'] as num?)?.toInt();
    final simSlot = (event['simSlot'] as num?)?.toInt();
    return IncomingSms(
      id: _uuid.v4(),
      sender: sender,
      body: body,
      receivedAt: millis != null && millis > 0
          ? DateTime.fromMillisecondsSinceEpoch(millis)
          : DateTime.now(),
      simSlot: simSlot != null && simSlot >= 0 ? simSlot : null,
    );
  }
}
