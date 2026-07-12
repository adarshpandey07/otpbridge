import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:otpbridge/app/providers.dart';
import 'package:otpbridge/app/router.dart';
import 'package:otpbridge/core/theme/app_colors.dart';
import 'package:otpbridge/core/theme/app_spacing.dart';
import 'package:otpbridge/core/widgets/widgets.dart';
import 'package:otpbridge/domain/services/sms_gateway.dart';
import 'package:otpbridge/features/onboarding/widgets/onboarding_widgets.dart';

/// First-run onboarding: what OTPBridge does, how it works, privacy,
/// permissions, get started. Completing sets `onboardingComplete`.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const int _pageCount = 5;

  final PageController _controller = PageController();
  int _page = 0;

  PlatformCapabilities? _capabilities;
  bool _permissionsGranted = false;
  bool _permissionRequested = false;
  bool _requesting = false;
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    _loadPlatformState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadPlatformState() async {
    final gateway = ref.read(smsGatewayProvider);
    try {
      final capabilities = await gateway.capabilities();
      final granted = await gateway.hasPermissions();
      if (!mounted) return;
      setState(() {
        _capabilities = capabilities;
        _permissionsGranted = granted;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _capabilities = const PlatformCapabilities.companion());
    }
  }

  Future<void> _requestPermissions() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    var granted = false;
    try {
      granted = await ref.read(smsGatewayProvider).requestPermissions();
    } catch (_) {
      granted = false;
    }
    if (!mounted) return;
    setState(() {
      _requesting = false;
      _permissionRequested = true;
      _permissionsGranted = granted;
    });
  }

  Future<void> _complete() async {
    if (_completing) return;
    setState(() => _completing = true);
    try {
      final repo = ref.read(settingsRepositoryProvider);
      final current = await repo.get();
      await repo.save(current.copyWith(onboardingComplete: true));
    } finally {
      if (mounted) setState(() => _completing = false);
    }
    if (!mounted) return;
    context.go(Routes.dashboard);
  }

  void _next() {
    _controller.nextPage(duration: AppMotion.base, curve: AppMotion.enter);
  }

  void _back() {
    _controller.previousPage(duration: AppMotion.base, curve: AppMotion.exit);
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pageCount - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _welcomePage(),
                  _howItWorksPage(),
                  _privacyPage(),
                  _permissionsPage(),
                  _getStartedPage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.sm,
                AppSpacing.screenH,
                AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PageDots(count: _pageCount, index: _page),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      if (_page > 0) ...[
                        SizedBox(
                          width: 52,
                          height: 52,
                          child: OutlinedButton(
                            onPressed: _back,
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(52, 52),
                            ),
                            child: const Icon(Icons.arrow_back_rounded,
                                size: 20),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Expanded(
                        child: FilledButton(
                          onPressed: _completing
                              ? null
                              : (isLast ? _complete : _next),
                          child: _completing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5),
                                )
                              : Text(isLast ? 'Get started' : 'Continue'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Pages ────────────────────────────────────────────────────────────────

  Widget _welcomePage() {
    return const OnboardingPage(
      icon: Icons.swap_horiz_rounded,
      title: 'Welcome to OTPBridge',
      body: 'Forward only the OTPs you choose — to exactly the right person.',
      children: [
        FeatureRow(
          icon: Icons.verified_user_outlined,
          title: 'Built for trust',
          description:
              'Nothing is forwarded without a rule you created — you decide '
              'what leaves your phone, always.',
        ),
        FeatureRow(
          icon: Icons.family_restroom_rounded,
          title: 'For the people who need it',
          description:
              'Family, assistants, teams — share codes safely instead of '
              'sharing your whole inbox.',
        ),
      ],
    );
  }

  Widget _howItWorksPage() {
    return const OnboardingPage(
      icon: Icons.route_outlined,
      title: 'How it works',
      body: 'Three small steps between an incoming SMS and a safe forward.',
      children: [
        FeatureRow(
          icon: Icons.auto_awesome_outlined,
          title: '1 · AI reads the message',
          description:
              'On-device AI spots the OTP, the sender and the amount.',
        ),
        FeatureRow(
          icon: Icons.rule_rounded,
          title: '2 · Your rules decide',
          description:
              'Categories, amounts and schedules choose forward, hold or block.',
        ),
        FeatureRow(
          icon: Icons.send_rounded,
          title: '3 · Secure forward',
          description:
              'The code goes to your chosen recipient — and only to them.',
        ),
      ],
    );
  }

  Widget _privacyPage() {
    return const OnboardingPage(
      icon: Icons.shield_outlined,
      title: 'Private by design',
      body: 'Your messages are yours. OTPBridge is built to keep it that way.',
      children: [
        FeatureRow(
          icon: Icons.smartphone_outlined,
          title: 'On-device AI',
          description:
              'Classification runs on your phone. Messages never leave it '
              'for analysis.',
        ),
        FeatureRow(
          icon: Icons.enhanced_encryption_outlined,
          title: 'AES-encrypted storage',
          description:
              'Rules, recipients and history are stored encrypted on-device.',
        ),
        FeatureRow(
          icon: Icons.do_not_disturb_alt_outlined,
          title: 'Nothing sold, ever',
          description:
              'No ads, no data brokers, no analytics on your messages.',
        ),
        FeatureRow(
          icon: Icons.tune_rounded,
          title: 'You stay in control',
          description:
              'Pause listening, revoke permissions or wipe everything at '
              'any time.',
        ),
      ],
    );
  }

  Widget _permissionsPage() {
    final canReadSms = _capabilities?.canReadSms ?? false;
    final loaded = _capabilities != null;

    return OnboardingPage(
      icon: Icons.key_outlined,
      title: 'Permissions',
      body: canReadSms
          ? 'Two permissions make automatic forwarding possible. Both are '
              'optional — you can grant them later.'
          : 'A quick, honest note about what OTPBridge can do on this device.',
      children: [
        const FeatureRow(
          icon: Icons.sms_outlined,
          title: 'SMS access',
          description:
              'Lets OTPBridge read incoming messages to find OTPs. Used for '
              'nothing else.',
        ),
        const FeatureRow(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          description:
              'So you can approve high-risk OTPs the moment they arrive.',
        ),
        FeatureRow(
          icon: Icons.phone_iphone_rounded,
          title: 'Android-only auto-reading',
          description: canReadSms
              ? 'Automatic SMS reading works on Android. On iPhone, '
                  'OTPBridge runs in companion mode.'
              : 'This device does not allow automatic SMS reading, so '
                  'OTPBridge runs in companion mode: manage rules, '
                  'recipients and history here.',
        ),
        if (loaded && canReadSms) _permissionAction(),
        if (loaded && !canReadSms)
          const Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(
              label: 'Companion mode on this device',
              tone: PillTone.info,
              icon: Icons.info_outline_rounded,
            ),
          ),
      ],
    );
  }

  Widget _permissionAction() {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    if (_permissionsGranted) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: StatusPill(
          label: 'Permissions granted',
          tone: PillTone.success,
          icon: Icons.check_circle_outline_rounded,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _requesting ? null : _requestPermissions,
          style: OutlinedButton.styleFrom(foregroundColor: t.primary),
          icon: _requesting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.verified_user_outlined, size: 20),
          label: Text(
              _permissionRequested ? 'Grant again' : 'Grant permissions'),
        ),
        if (_permissionRequested && !_permissionsGranted)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              'Not granted yet — you can finish setup now and grant it '
              'later from Settings.',
              style: text.bodySmall?.copyWith(color: t.warning),
            ),
          ),
      ],
    );
  }

  Widget _getStartedPage() {
    return const OnboardingPage(
      icon: Icons.verified_outlined,
      title: "You're all set",
      body: 'Create your first rule, add a trusted recipient, and OTPBridge '
          'quietly handles the rest.',
      children: [
        FeatureRow(
          icon: Icons.dashboard_outlined,
          title: 'Dashboard',
          description:
              'A calm overview of recent OTPs and anything waiting for you.',
        ),
        FeatureRow(
          icon: Icons.gpp_good_outlined,
          title: 'Safe defaults',
          description:
              'High-risk banking OTPs always ask for your approval first.',
        ),
      ],
    );
  }
}
