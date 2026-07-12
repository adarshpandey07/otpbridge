/// Build-time configuration. Override via `--dart-define` in CI/release, e.g.
/// `flutter build apk --dart-define=RAZORPAY_KEY_ID=rzp_live_xxx`.
abstract final class AppConfig {
  /// Razorpay publishable key id. Empty = demo mode (checkout is simulated so
  /// the flow is testable without real credentials).
  static const String razorpayKeyId =
      String.fromEnvironment('RAZORPAY_KEY_ID', defaultValue: '');

  /// Optional backend base URL for server-side payment verification and sync.
  static const String backendBaseUrl =
      String.fromEnvironment('BACKEND_BASE_URL', defaultValue: '');

  static bool get hasRazorpayKey => razorpayKeyId.isNotEmpty;
  static bool get hasBackend => backendBaseUrl.isNotEmpty;

  /// Business/merchant details shown on the checkout sheet.
  static const String merchantName = 'OTPBridge';
  static const String supportEmail = 'support@otpbridge.app';
}
