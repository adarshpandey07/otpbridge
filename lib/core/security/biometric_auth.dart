import 'package:local_auth/local_auth.dart';

/// Thin wrapper over local_auth for fingerprint / face unlock.
class BiometricAuth {
  BiometricAuth([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// Whether the device has biometric hardware the user has enrolled.
  Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Prompt for biometric (with device PIN/pattern fallback available).
  /// Returns true only on a successful authentication.
  Future<bool> authenticate({
    String reason = 'Unlock OTPBridge',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
