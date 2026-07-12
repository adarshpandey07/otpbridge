import 'package:flutter/material.dart';

import 'package:otpbridge/core/theme/app_colors.dart';
import 'package:otpbridge/core/theme/app_spacing.dart';

/// Prominent, Play-policy-compliant disclosure shown BEFORE OTPBridge ever
/// requests or uses SMS access.
///
/// Returns `true` only when the user explicitly taps **Allow**. Dismissing the
/// sheet or tapping **Not now** returns `false`, and the caller must not enable
/// any SMS reading in that case.
Future<bool> showSmsConsent(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _SmsConsentSheet(),
  );
  return result ?? false;
}

class _SmsConsentSheet extends StatelessWidget {
  const _SmsConsentSheet();

  static const List<(IconData, String)> _points = [
    (
      Icons.phone_android_outlined,
      'Messages are read and classified entirely on your device.',
    ),
    (
      Icons.lock_outline_rounded,
      'Your message content is never sold, shared or uploaded to a server.',
    ),
    (
      Icons.rule_folder_outlined,
      'Only the OTPs your rules match are forwarded — nothing else '
          'leaves your phone.',
    ),
    (
      Icons.toggle_off_outlined,
      'You can turn this off at any time in Settings.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.xs,
            AppSpacing.screenH,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.primarySubtle,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(Icons.sms_outlined,
                    size: 26, color: t.onPrimarySubtle),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Allow OTPBridge to read incoming SMS?',
                  style: text.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Turning this on lets OTPBridge read incoming text messages on '
                'this device to automatically detect one-time passcodes (OTPs) '
                'and forward them to the people you choose, following the rules '
                'you set up.',
                style: text.bodyMedium?.copyWith(color: t.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final (icon, label) in _points) ...[
                _ConsentPoint(icon: icon, label: label),
                const SizedBox(height: AppSpacing.sm),
              ],
              const SizedBox(height: AppSpacing.xs),
              InkWell(
                onTap: () => _showPrivacyPolicy(context),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.description_outlined,
                          size: 18, color: t.primary),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Read our privacy policy',
                        style: text.bodyMedium?.copyWith(
                          color: t.primary,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: t.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, AppSpacing.touchTarget),
                        foregroundColor: t.textSecondary,
                      ),
                      child: const Text('Not now'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, AppSpacing.touchTarget),
                      ),
                      child: const Text('Allow'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Privacy policy'),
        content: const Text(
          'OTPBridge reads and classifies incoming SMS entirely on your '
          'device. Message content is stored AES-encrypted on your phone and '
          'is never sold, shared or uploaded. Only the OTPs your rules match '
          'are forwarded to the recipients you choose — nothing else leaves '
          'your device. You can disable SMS reading at any time in Settings.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _ConsentPoint extends StatelessWidget {
  const _ConsentPoint({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.surfaceSunken,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, size: 18, color: t.textSecondary),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: t.textPrimary),
            ),
          ),
        ),
      ],
    );
  }
}
