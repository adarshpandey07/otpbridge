import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:otpbridge/app/providers.dart';
import 'package:otpbridge/core/theme/app_colors.dart';
import 'package:otpbridge/core/theme/app_spacing.dart';
import 'package:otpbridge/features/security/pin_keypad.dart';

/// Pushes the PIN setup flow as a full-screen dialog.
///
/// Returns true when a new PIN was saved, false when the user backed out.
/// With [change] the user must verify their current PIN before choosing a
/// new one.
Future<bool> setupPin(BuildContext context, {bool change = false}) async {
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PinSetupScreen(change: change),
    ),
  );
  return result ?? false;
}

enum _Phase { verify, create, confirm }

/// Two-step PIN setup: enter a 4-digit PIN, then re-enter it to confirm.
/// In change mode a "verify current PIN" step comes first.
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key, this.change = false});

  /// When true, the current PIN is verified before a new one can be set.
  final bool change;

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  static const int _pinLength = 4;

  _Phase _phase = _Phase.create;
  String _entered = '';
  String _first = '';
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.change) {
      _phase = _Phase.verify;
      // If no PIN exists (shouldn't happen), skip straight to creating one.
      ref.read(pinStoreProvider).hasPin().then((has) {
        if (mounted && !has) setState(() => _phase = _Phase.create);
      });
    }
  }

  String get _title => switch (_phase) {
        _Phase.verify => 'Enter your current PIN',
        _Phase.create => widget.change ? 'Choose a new PIN' : 'Create a PIN',
        _Phase.confirm => 'Confirm your PIN',
      };

  String get _subtitle => switch (_phase) {
        _Phase.verify => 'Confirm it’s you before changing your PIN',
        _Phase.create => 'You’ll use it to unlock OTPBridge',
        _Phase.confirm => 'Re-enter the same 4 digits',
      };

  Future<void> _onDigit(String digit) async {
    if (_busy || _entered.length >= _pinLength) return;
    setState(() {
      _entered += digit;
      _error = null;
    });
    if (_entered.length < _pinLength) return;

    final pin = _entered;
    _busy = true;
    // Let the last dot fill before advancing.
    await Future<void>.delayed(AppMotion.fast);
    if (!mounted) return;

    switch (_phase) {
      case _Phase.verify:
        final ok = await ref.read(pinStoreProvider).verify(pin);
        if (!mounted) return;
        if (ok) {
          setState(() {
            _phase = _Phase.create;
            _entered = '';
            _busy = false;
          });
        } else {
          HapticFeedback.heavyImpact();
          setState(() {
            _entered = '';
            _error = 'Incorrect PIN. Try again.';
            _busy = false;
          });
        }
      case _Phase.create:
        setState(() {
          _first = pin;
          _entered = '';
          _phase = _Phase.confirm;
          _busy = false;
        });
      case _Phase.confirm:
        if (pin == _first) {
          await ref.read(pinStoreProvider).setPin(pin);
          if (!mounted) return;
          Navigator.of(context).pop(true);
        } else {
          HapticFeedback.heavyImpact();
          setState(() {
            _phase = _Phase.create;
            _first = '';
            _entered = '';
            _error = 'PINs didn’t match. Start over.';
            _busy = false;
          });
        }
    }
  }

  void _backspace() {
    if (_busy || _entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: t.primarySubtle,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(
                  _phase == _Phase.verify
                      ? Icons.lock_rounded
                      : Icons.pin_rounded,
                  color: t.onPrimarySubtle,
                  size: 30,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AnimatedSwitcher(
                duration: AppMotion.base,
                switchInCurve: AppMotion.enter,
                switchOutCurve: AppMotion.exit,
                child: Text(
                  _title,
                  key: ValueKey(_title),
                  textAlign: TextAlign.center,
                  style: text.headlineSmall,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _error ?? _subtitle,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: _error != null ? t.danger : t.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              PinDots(filled: _entered.length, error: _error != null),
              const Spacer(flex: 2),
              PinKeypad(
                onDigit: _onDigit,
                onBackspace: _backspace,
                enabled: !_busy,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
