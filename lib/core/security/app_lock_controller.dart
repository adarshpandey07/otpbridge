import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_settings.dart';
import 'biometric_auth.dart';
import 'pin_store.dart';

enum LockPhase { uninitialized, locked, unlocked }

class AppLockState {
  const AppLockState({
    this.phase = LockPhase.uninitialized,
    this.enabled = false,
    this.biometricEnabled = false,
    this.checking = false,
    this.error,
  });

  final LockPhase phase;
  final bool enabled;
  final bool biometricEnabled;
  final bool checking;
  final String? error;

  /// True when the lock screen must cover the app.
  bool get isGating => enabled && phase != LockPhase.unlocked;

  AppLockState copyWith({
    LockPhase? phase,
    bool? enabled,
    bool? biometricEnabled,
    bool? checking,
    String? error,
    bool clearError = false,
  }) =>
      AppLockState(
        phase: phase ?? this.phase,
        enabled: enabled ?? this.enabled,
        biometricEnabled: biometricEnabled ?? this.biometricEnabled,
        checking: checking ?? this.checking,
        error: clearError ? null : (error ?? this.error),
      );
}

/// Owns the app-lock state machine: gates the app on cold launch and after a
/// background timeout, and authenticates via biometric or PIN.
class AppLockController extends StateNotifier<AppLockState> {
  AppLockController({
    required PinStore pinStore,
    required BiometricAuth biometric,
    DateTime Function() clock = DateTime.now,
  })  : _pin = pinStore,
        _bio = biometric,
        _clock = clock,
        super(const AppLockState());

  final PinStore _pin;
  final BiometricAuth _bio;
  final DateTime Function() _clock;

  int _timeoutMinutes = 0;
  DateTime? _backgroundedAt;

  PinStore get pinStore => _pin;
  BiometricAuth get biometric => _bio;

  /// Called when settings first load and whenever they change.
  void applySettings(AppSettings s) {
    _timeoutMinutes = s.appLockAfterMinutes;
    if (!s.appLockEnabled) {
      state = state.copyWith(
        enabled: false,
        biometricEnabled: s.biometricEnabled,
        phase: LockPhase.unlocked,
      );
      return;
    }
    // Lock is enabled.
    final phase =
        state.phase == LockPhase.uninitialized ? LockPhase.locked : state.phase;
    state = state.copyWith(
      enabled: true,
      biometricEnabled: s.biometricEnabled,
      phase: phase,
    );
  }

  void onPaused() {
    _backgroundedAt = _clock();
  }

  void onResumed() {
    if (!state.enabled || state.phase == LockPhase.locked) return;
    final since = _backgroundedAt;
    if (since == null) return;
    final elapsed = _clock().difference(since);
    if (_timeoutMinutes <= 0 ||
        elapsed >= Duration(minutes: _timeoutMinutes)) {
      state = state.copyWith(phase: LockPhase.locked, clearError: true);
    }
    _backgroundedAt = null;
  }

  void lockNow() {
    if (state.enabled) {
      state = state.copyWith(phase: LockPhase.locked, clearError: true);
    }
  }

  Future<bool> unlockWithBiometric() async {
    state = state.copyWith(checking: true, clearError: true);
    final ok = await _bio.authenticate(reason: 'Unlock OTPBridge');
    if (ok) {
      state = state.copyWith(phase: LockPhase.unlocked, checking: false);
    } else {
      state = state.copyWith(checking: false);
    }
    return ok;
  }

  Future<bool> unlockWithPin(String pin) async {
    state = state.copyWith(checking: true, clearError: true);
    final ok = await _pin.verify(pin);
    if (ok) {
      state = state.copyWith(phase: LockPhase.unlocked, checking: false);
    } else {
      state = state.copyWith(
          checking: false, error: 'Incorrect PIN. Try again.');
    }
    return ok;
  }

  Future<bool> hasPin() => _pin.hasPin();
}
