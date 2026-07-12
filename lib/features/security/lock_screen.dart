import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'pin_keypad.dart';

/// Full-screen lock shown over the app when [AppLockState.isGating]. Offers
/// biometric (if enabled) and a PIN fallback.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  static const int _pinLength = 4;
  String _entered = '';
  bool _promptedBiometric = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeBiometric());
  }

  Future<void> _maybeBiometric() async {
    if (_promptedBiometric) return;
    _promptedBiometric = true;
    final state = ref.read(appLockControllerProvider);
    if (state.biometricEnabled) {
      await ref.read(appLockControllerProvider.notifier).unlockWithBiometric();
    }
  }

  Future<void> _onKey(String digit) async {
    if (_entered.length >= _pinLength) return;
    setState(() => _entered += digit);
    if (_entered.length == _pinLength) {
      final ok = await ref
          .read(appLockControllerProvider.notifier)
          .unlockWithPin(_entered);
      if (!ok && mounted) {
        HapticFeedback.heavyImpact();
        setState(() => _entered = '');
      }
    }
  }

  void _backspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final state = ref.watch(appLockControllerProvider);

    return Material(
      color: t.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: t.primarySubtle,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child:
                    Icon(Icons.lock_rounded, color: t.onPrimarySubtle, size: 30),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('OTPBridge is locked',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                state.error ?? 'Enter your PIN to continue',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: state.error != null ? t.danger : t.textTertiary),
              ),
              const SizedBox(height: AppSpacing.xl),
              PinDots(filled: _entered.length, error: state.error != null),
              const Spacer(flex: 2),
              PinKeypad(
                onDigit: _onKey,
                onBackspace: _backspace,
                enabled: !state.checking,
                leftIcon:
                    state.biometricEnabled ? Icons.fingerprint_rounded : null,
                onLeftTap:
                    state.biometricEnabled ? _maybeBiometricRetry : null,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _maybeBiometricRetry() async {
    await ref.read(appLockControllerProvider.notifier).unlockWithBiometric();
  }
}
