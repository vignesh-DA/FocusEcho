import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../theme/app_theme.dart';
import '../../features/analytics/analytics_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/focus_session/focus_session_screen.dart';
import '../../features/onboarding/app_selector/app_selector_screen.dart';
import '../../features/onboarding/consent/consent_screen.dart';
import '../../features/onboarding/permission_wizard/permission_wizard_screen.dart';
import '../../features/onboarding/splash/splash_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/app_limits_screen.dart';
import '../../features/streaks_xp/streaks_xp_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  static late GoRouter _router;
  static final ValueNotifier<int> refreshNotifier = ValueNotifier(0);

  /// Call this after any permission or consent change to re-evaluate redirects.
  static void refresh() => refreshNotifier.value++;

  static void initialize(SharedPreferences prefs) {
    _router = GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: AppRoutes.splash,
      refreshListenable: refreshNotifier,
      redirect: (context, state) {
        final consentGiven = prefs.getBool(AppKeys.consentGiven) ?? false;
        final usage = prefs.getBool('has_usage_access') ?? false;
        final accessibility = prefs.getBool('has_accessibility') ?? false;
        final battery = prefs.getBool('has_battery_optimization') ?? false;
        final permissionsReady = kIsWeb || (usage && accessibility && battery);
        final path = state.uri.path;

        // Allow splash and consent screens unconditionally
        if (path == AppRoutes.splash) return null;

        if (!consentGiven && path != AppRoutes.consent) {
          return AppRoutes.consent;
        }

        if (consentGiven &&
            !permissionsReady &&
            path != AppRoutes.permissionWizard &&
            path != AppRoutes.consent) {
          return AppRoutes.permissionWizard;
        }
        return null;
      },
      routes: [
        GoRoute(
          name: 'splash',
          path: AppRoutes.splash,
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          name: 'consent',
          path: AppRoutes.consent,
          builder: (context, state) => const ConsentScreen(),
        ),
        GoRoute(
          name: 'permissionWizard',
          path: AppRoutes.permissionWizard,
          builder: (context, state) => const PermissionWizardScreen(),
        ),
        GoRoute(
          name: 'appSelector',
          path: AppRoutes.appSelector,
          builder: (context, state) => const AppSelectorScreen(),
        ),
        GoRoute(
          name: 'focusSession',
          path: AppRoutes.focusSession,
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => const FocusSessionScreen(),
        ),

        // ── Main app shell with bottom navigation ──────────────────
        ShellRoute(
          navigatorKey: _shellNavigatorKey,
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(
              name: 'dashboard',
              path: AppRoutes.dashboard,
              builder: (context, state) => const DashboardScreen(),
            ),
            GoRoute(
              name: 'analytics',
              path: AppRoutes.analytics,
              builder: (context, state) => const AnalyticsScreen(),
            ),
            GoRoute(
              name: 'streaksXp',
              path: AppRoutes.streaksXp,
              builder: (context, state) => const StreaksXpScreen(),
            ),
            GoRoute(
              name: 'settings',
              path: AppRoutes.settings,
              builder: (context, state) => const SettingsScreen(),
              routes: [
                GoRoute(
                  path: 'app-limits',
                  builder: (context, state) => const AppLimitsScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static GoRouter get router => _router;
}

/// Persistent bottom navigation bar wrapping the main app screens.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    AppRoutes.dashboard,
    AppRoutes.analytics,
    AppRoutes.streaksXp,
    AppRoutes.settings,
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final idx = _tabs.indexOf(location);
    return idx >= 0 ? idx : 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.accentBlue.withValues(alpha: 0.15),
        onDestinationSelected: (i) => context.go(_tabs[i]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: AppColors.accentBlue),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart, color: AppColors.accentBlue),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department, color: AppColors.accentYellow),
            label: 'Streaks',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: AppColors.accentBlue),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
