import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:otpbridge/core/theme/app_colors.dart';
import 'package:otpbridge/core/theme/app_spacing.dart';

/// Circular digit keypad shared by [LockScreen] and [PinSetupScreen].
///
/// Bottom row: an optional left action (e.g. biometric retry), the 0 key and
/// a backspace key. Every key is a 76dp circle (≥48dp touch target) and taps
/// give subtle haptic feedback.
class PinKeypad extends StatelessWidget {
  const PinKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.leftIcon,
    this.onLeftTap,
    this.enabled = true,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  /// Optional bottom-left key (e.g. [Icons.fingerprint_rounded]).
  final IconData? leftIcon;
  final VoidCallback? onLeftTap;

  /// When false all keys are inert (e.g. while verifying).
  final bool enabled;

  static const double _keySize = 76;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final digitStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: t.textPrimary,
        );

    Widget key({String? label, Widget? child, VoidCallback? onTap}) =>
        SizedBox(
          width: _keySize,
          height: _keySize,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? onTap : null,
              child: Center(child: child ?? Text(label!, style: digitStyle)),
            ),
          ),
        );

    Widget digit(String d) => key(
          label: d,
          onTap: () {
            HapticFeedback.selectionClick();
            onDigit(d);
          },
        );

    Widget row(List<Widget> children) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: children,
        );

    return Column(
      children: [
        row([digit('1'), digit('2'), digit('3')]),
        row([digit('4'), digit('5'), digit('6')]),
        row([digit('7'), digit('8'), digit('9')]),
        row([
          if (leftIcon != null && onLeftTap != null)
            key(
              child: Icon(leftIcon, size: 30, color: t.primary),
              onTap: onLeftTap,
            )
          else
            const SizedBox(width: _keySize, height: _keySize),
          digit('0'),
          key(
            child: Icon(Icons.backspace_outlined,
                size: 24, color: t.textSecondary),
            onTap: () {
              HapticFeedback.selectionClick();
              onBackspace();
            },
          ),
        ]),
      ],
    );
  }
}

/// Row of dots showing how many PIN digits have been entered.
class PinDots extends StatelessWidget {
  const PinDots({
    super.key,
    required this.filled,
    this.length = 4,
    this.error = false,
  });

  final int filled;
  final int length;

  /// Tints the dots with the danger token (e.g. after a wrong PIN).
  final bool error;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final active = error ? t.danger : t.primary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final isFilled = i < filled;
        return AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.enter,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs + 2),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? active : Colors.transparent,
            border: Border.all(
              color: isFilled
                  ? active
                  : (error ? t.danger : t.borderStrong),
              width: 2,
            ),
          ),
        );
      }),
    );
  }
}
