import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/security/lock_screen.dart';
import 'providers.dart';
import 'router.dart';

class OtpBridgeApp extends ConsumerWidget {
  const OtpBridgeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsProvider);
    final themeMode = settings.valueOrNull?.themeMode ?? ThemeMode.system;

    return MaterialApp.router(
      title: 'OTPBridge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) => _LockGate(child: child ?? const SizedBox()),
    );
  }
}

/// Observes app lifecycle and overlays the [LockScreen] whenever the app-lock
/// state machine says the app should be gated (cold launch + resume timeout).
class _LockGate extends ConsumerStatefulWidget {
  const _LockGate({required this.child});
  final Widget child;

  @override
  ConsumerState<_LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<_LockGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(appLockControllerProvider.notifier);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        controller.onPaused();
      case AppLifecycleState.resumed:
        controller.onResumed();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  bool _appliedInitial = false;

  @override
  Widget build(BuildContext context) {
    // Keep the lock controller in sync with settings changes (fires when the
    // stream goes loading → data and on every later change; runs off-build).
    ref.listen(settingsProvider, (_, next) {
      final s = next.valueOrNull;
      if (s != null) {
        ref.read(appLockControllerProvider.notifier).applySettings(s);
      }
    });

    // Apply the already-available value once, after the frame (safe to mutate
    // the notifier outside build).
    if (!_appliedInitial) {
      final s = ref.read(settingsProvider).valueOrNull;
      if (s != null) {
        _appliedInitial = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(appLockControllerProvider.notifier).applySettings(s);
          }
        });
      }
    }

    final lock = ref.watch(appLockControllerProvider);

    return Stack(
      children: [
        widget.child,
        if (lock.isGating) const Positioned.fill(child: LockScreen()),
      ],
    );
  }
}
