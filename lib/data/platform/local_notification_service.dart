import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../domain/models/models.dart';
import '../../domain/services/notification_service.dart';

/// [NotificationService] implementation backed by flutter_local_notifications.
///
/// Four Android channels are created up front:
///  - `forwards`  — confirmations when an OTP is forwarded (default importance)
///  - `approvals` — high-risk OTPs waiting on the user (high importance)
///  - `status`    — queue updates and the ongoing listening indicator (low)
///  - `alerts`    — blocked messages, suggestions, subscription notices
///
/// Every platform call is guarded so tests / unsupported platforms no-op.
class LocalNotificationService implements NotificationService {
  LocalNotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Stable notification IDs, one per event type: a newer notification of the
  // same type replaces the previous one instead of piling up.
  static const int _idForwarded = 1001;
  static const int _idQueued = 1002;
  static const int _idRetrying = 1003;
  static const int _idBlocked = 1004;
  static const int _idApproval = 2001;
  static const int _idSuggestion = 3001;
  static const int _idSubscription = 3002;
  static const int _idListening = 4001;

  static const AndroidNotificationChannel _forwardsChannel =
      AndroidNotificationChannel(
    'forwards',
    'Forwarded OTPs',
    description: 'Confirmations when an OTP is forwarded to a recipient',
    importance: Importance.defaultImportance,
  );

  static const AndroidNotificationChannel _approvalsChannel =
      AndroidNotificationChannel(
    'approvals',
    'Approvals',
    description: 'High-risk OTPs that need your approval before forwarding',
    importance: Importance.high,
  );

  static const AndroidNotificationChannel _statusChannel =
      AndroidNotificationChannel(
    'status',
    'Status',
    description: 'Listening status and delivery queue updates',
    importance: Importance.low,
  );

  static const AndroidNotificationChannel _alertsChannel =
      AndroidNotificationChannel(
    'alerts',
    'Alerts',
    description: 'Blocked messages, suggestions and subscription notices',
    importance: Importance.defaultImportance,
  );

  static const List<AndroidNotificationChannel> _channels = [
    _forwardsChannel,
    _approvalsChannel,
    _statusChannel,
    _alertsChannel,
  ];

  @override
  Future<void> init() async {
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(settings);

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        for (final channel in _channels) {
          await android.createNotificationChannel(channel);
        }
      }
      _initialized = true;
    } on Exception {
      // Plugin unavailable (tests / unsupported platform) — stay a no-op.
      _initialized = false;
    }
  }

  @override
  Future<void> showForwarded(HistoryEntry entry, {bool maskOtp = true}) async {
    final c = entry.classification;
    final source = _sourceOf(c);
    final code = c.hasOtp ? (maskOtp ? '••••' : c.otp!) : null;
    final to = entry.recipientNames.isEmpty
        ? 'your recipient'
        : entry.recipientNames.join(', ');
    final body = code != null
        ? '$source code $code sent to $to'
        : '$source message sent to $to';
    await _show(
      id: _idForwarded,
      channel: _forwardsChannel,
      title: 'OTP forwarded',
      body: body,
    );
  }

  @override
  Future<void> showQueued(ForwardTask task) async {
    final source = _sourceOf(task.classification);
    await _show(
      id: _idQueued,
      channel: _statusChannel,
      title: 'Forward queued',
      body:
          '$source code for ${task.recipientName} will be sent once you are back online',
    );
  }

  @override
  Future<void> showRetrying(ForwardTask task) async {
    final source = _sourceOf(task.classification);
    await _show(
      id: _idRetrying,
      channel: _statusChannel,
      title: 'Retrying delivery',
      body:
          'Resending $source code to ${task.recipientName} — attempt ${task.attempts} of ${ForwardTask.maxAttempts}',
    );
  }

  @override
  Future<void> showBlocked(HistoryEntry entry) async {
    final source = _sourceOf(entry.classification);
    final why = entry.detail ??
        (entry.ruleName != null
            ? 'Blocked by rule "${entry.ruleName}"'
            : 'Blocked by your rules');
    await _show(
      id: _idBlocked,
      channel: _alertsChannel,
      title: 'OTP blocked',
      body: '$source message was not forwarded. $why',
    );
  }

  @override
  Future<void> showApprovalNeeded(PendingApproval approval) async {
    final source = _sourceOf(approval.classification);
    final minutesLeft = approval.expiresAt
        .difference(DateTime.now())
        .inMinutes
        .clamp(1, 24 * 60);
    final reason = approval.reason ?? 'This OTP needs your review';
    await _show(
      id: _idApproval,
      channel: _approvalsChannel,
      title: 'Approval needed — $source',
      body: '$reason. Expires in $minutesLeft min.',
      category: AndroidNotificationCategory.reminder,
    );
  }

  @override
  Future<void> showSuggestion(AiSuggestion suggestion) async {
    await _show(
      id: _idSuggestion,
      channel: _alertsChannel,
      title: suggestion.title.isEmpty
          ? 'Automation suggestion'
          : suggestion.title,
      body: suggestion.body,
    );
  }

  @override
  Future<void> showSubscriptionExpired() async {
    await _show(
      id: _idSubscription,
      channel: _alertsChannel,
      title: 'Subscription expired',
      body: 'Forwarding is paused. Renew to keep your OTPs flowing.',
    );
  }

  @override
  Future<void> showListeningStatus({required bool active}) async {
    if (!active) {
      try {
        await _plugin.cancel(_idListening);
      } on Exception {
        // Ignore — nothing to dismiss on unsupported platforms.
      }
      return;
    }
    await _show(
      id: _idListening,
      channel: _statusChannel,
      title: 'OTPBridge is listening',
      body: 'Watching incoming SMS for OTPs to forward',
      ongoing: true,
    );
  }

  /// Prefer the classified brand, then merchant, then the raw sender.
  static String _sourceOf(SmsClassification c) {
    final brand = c.brand;
    if (brand != null && brand.isNotEmpty) return brand;
    final merchant = c.merchant;
    if (merchant != null && merchant.isNotEmpty) return merchant;
    return c.sms.sender.isEmpty ? 'OTP' : c.sms.sender;
  }

  Future<void> _show({
    required int id,
    required AndroidNotificationChannel channel,
    required String title,
    required String body,
    bool ongoing = false,
    AndroidNotificationCategory? category,
  }) async {
    if (!_initialized) return;
    try {
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: switch (channel.importance) {
            Importance.high || Importance.max => Priority.high,
            Importance.low || Importance.min => Priority.low,
            _ => Priority.defaultPriority,
          },
          ongoing: ongoing,
          autoCancel: !ongoing,
          onlyAlertOnce: ongoing,
          showWhen: !ongoing,
          category: category,
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(),
      );
      await _plugin.show(id, title, body, details);
    } on Exception {
      // Never let a notification failure break the pipeline.
    }
  }
}
