import '../models/forward_task.dart';
import '../models/recipient.dart';
import 'sms_gateway.dart';

/// Extensible delivery-channel contract. Register new channels (WhatsApp,
/// Telegram, Email, custom webhooks) by implementing this and adding to the
/// [ChannelRegistry] — no changes needed in the queue processor.
abstract interface class ForwardChannelPlugin {
  ForwardChannel get channel;

  /// Whether this channel can be used right now (configured + platform-capable).
  Future<bool> isAvailable();

  /// Attempt delivery of one task. Must be idempotent-safe for retries.
  Future<SmsSendResult> deliver(ForwardTask task);
}

/// SMS delivery backed by the native [SmsGateway].
class SmsChannelPlugin implements ForwardChannelPlugin {
  SmsChannelPlugin(this._gateway);
  final SmsGateway _gateway;

  @override
  ForwardChannel get channel => ForwardChannel.sms;

  @override
  Future<bool> isAvailable() async => (await _gateway.capabilities()).canSendSms;

  @override
  Future<SmsSendResult> deliver(ForwardTask task) =>
      _gateway.sendSms(to: task.destination, body: _compose(task));

  String _compose(ForwardTask task) {
    final c = task.classification;
    final brand = c.brand ?? c.category.label;
    final otp = c.otp ?? '(see message)';
    return 'OTPBridge · $brand OTP: $otp'
        '${c.amount != null ? ' · Amount ₹${c.amount!.toStringAsFixed(0)}' : ''}';
  }
}

/// Central registry of available channels.
class ChannelRegistry {
  ChannelRegistry(List<ForwardChannelPlugin> plugins)
      : _plugins = {for (final p in plugins) p.channel: p};

  final Map<ForwardChannel, ForwardChannelPlugin> _plugins;

  ForwardChannelPlugin? forChannel(ForwardChannel channel) => _plugins[channel];

  Future<List<ForwardChannel>> availableChannels() async {
    final result = <ForwardChannel>[];
    for (final p in _plugins.values) {
      if (await p.isAvailable()) result.add(p.channel);
    }
    return result;
  }
}
