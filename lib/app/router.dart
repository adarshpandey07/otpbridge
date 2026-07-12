import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/models/models.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/history/history_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/paywall/paywall_screen.dart';
import '../features/recipients/recipient_editor_screen.dart';
import '../features/recipients/recipients_screen.dart';
import '../features/rules/rule_editor_screen.dart';
import '../features/rules/rules_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/app_shell.dart';
import 'providers.dart';

abstract final class Routes {
  static const onboarding = '/onboarding';
  static const dashboard = '/dashboard';
  static const rules = '/rules';
  static const history = '/history';
  static const settings = '/settings';
  static const ruleEditor = '/rules/edit';
  static const recipients = '/recipients';
  static const recipientEditor = '/recipients/edit';
  static const paywall = '/paywall';
}

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final settings = ref.watch(settingsRepositoryProvider);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.dashboard,
    redirect: (context, state) async {
      final s = await settings.get();
      final onboarding = state.matchedLocation == Routes.onboarding;
      if (!s.onboardingComplete && !onboarding) return Routes.onboarding;
      if (s.onboardingComplete && onboarding) return Routes.dashboard;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: Routes.ruleEditor,
        parentNavigatorKey: _rootKey,
        builder: (_, state) => RuleEditorScreen(rule: state.extra as ForwardRule?),
      ),
      GoRoute(
        path: Routes.recipients,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const RecipientsScreen(),
      ),
      GoRoute(
        path: Routes.recipientEditor,
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            RecipientEditorScreen(recipient: state.extra as Recipient?),
      ),
      GoRoute(
        path: Routes.paywall,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const PaywallScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellKey,
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: Routes.dashboard,
            pageBuilder: (_, __) => _fade(const DashboardScreen()),
          ),
          GoRoute(
            path: Routes.rules,
            pageBuilder: (_, __) => _fade(const RulesScreen()),
          ),
          GoRoute(
            path: Routes.history,
            pageBuilder: (_, __) => _fade(const HistoryScreen()),
          ),
          GoRoute(
            path: Routes.settings,
            pageBuilder: (_, __) => _fade(const SettingsScreen()),
          ),
        ],
      ),
    ],
  );
});

CustomTransitionPage<void> _fade(Widget child) => CustomTransitionPage(
      child: child,
      transitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    );
