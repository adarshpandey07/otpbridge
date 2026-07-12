import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the app-lock PIN as a salted SHA-256 hash in the platform keystore.
/// The raw PIN is never persisted.
class PinStore {
  PinStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  static const _saltKey = 'otpbridge.lock.salt';
  static const _hashKey = 'otpbridge.lock.hash';

  Future<bool> hasPin() async {
    try {
      return (await _storage.read(key: _hashKey)) != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> setPin(String pin) async {
    final salt = _randomSalt();
    await _storage.write(key: _saltKey, value: salt);
    await _storage.write(key: _hashKey, value: _hash(pin, salt));
  }

  Future<bool> verify(String pin) async {
    try {
      final salt = await _storage.read(key: _saltKey);
      final hash = await _storage.read(key: _hashKey);
      if (salt == null || hash == null) return false;
      return _constantTimeEquals(_hash(pin, salt), hash);
    } catch (_) {
      return false;
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _saltKey);
    await _storage.delete(key: _hashKey);
  }

  static String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt::$pin')).toString();

  static String _randomSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64Encode(bytes);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
