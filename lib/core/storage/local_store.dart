import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// AES-encrypted Hive storage. The 256-bit box key is generated once and
/// kept in the platform keystore via flutter_secure_storage; all boxes are
/// opened with [HiveAesCipher] so data at rest is always encrypted.
class LocalStore {
  LocalStore._();

  static const String _keyName = 'otpbridge.hive.key';

  static const String rulesBox = 'rules';
  static const String recipientsBox = 'recipients';
  static const String groupsBox = 'groups';
  static const String historyBox = 'history';
  static const String queueBox = 'queue';
  static const String approvalsBox = 'approvals';
  static const String settingsBox = 'settings';
  static const String suggestionsBox = 'suggestions';
  static const String metaBox = 'meta';

  static const List<String> _allBoxes = [
    rulesBox, recipientsBox, groupsBox, historyBox, queueBox,
    approvalsBox, settingsBox, suggestionsBox, metaBox,
  ];

  late final HiveAesCipher _cipher;

  static Future<LocalStore> open({
    FlutterSecureStorage secureStorage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
  }) async {
    await Hive.initFlutter();
    final store = LocalStore._();

    var keyB64 = await secureStorage.read(key: _keyName);
    if (keyB64 == null) {
      final key = Hive.generateSecureKey();
      keyB64 = base64Encode(key);
      await secureStorage.write(key: _keyName, value: keyB64);
    }
    store._cipher = HiveAesCipher(base64Decode(keyB64));

    for (final name in _allBoxes) {
      await Hive.openBox<Map>(name, encryptionCipher: store._cipher);
    }
    return store;
  }

  /// Test-only: opens plain in-memory-ish boxes without platform keystore.
  static Future<LocalStore> openForTest(String path) async {
    Hive.init(path);
    final store = LocalStore._();
    for (final name in _allBoxes) {
      await Hive.openBox<Map>(name);
    }
    return store;
  }

  Box<Map> box(String name) => Hive.box<Map>(name);

  /// Typed read helper: values are stored as JSON maps.
  List<T> readAll<T>(
    String boxName,
    T Function(Map<String, dynamic>) fromJson,
  ) =>
      box(boxName)
          .values
          .map((raw) => fromJson(Map<String, dynamic>.from(raw)))
          .toList();

  Future<void> put(String boxName, String key, Map<String, dynamic> json) =>
      box(boxName).put(key, json);

  Future<void> delete(String boxName, String key) => box(boxName).delete(key);

  Future<void> wipeAll() async {
    for (final name in _allBoxes) {
      await box(name).clear();
    }
  }

  Future<void> close() => Hive.close();
}
