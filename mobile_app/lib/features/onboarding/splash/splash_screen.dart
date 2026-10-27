import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../focus_session/focus_session_viewmodel.dart';

/// Entry-point splash shown for ~2.5 seconds on every app launch.
///
/// MOB-3b: After the animation the screen checks [AppKeys.sessionActive]. If
/// a session was running when the OS killed the process, [resumeSession] is
/// called on [FocusSessionViewModel] which reads the active SQLite row, re-
/// wires the elapsed-time timer, and returns `true`. The app then routes
/// directly to [AppRoutes.focusSession] so the user is back where they left
/// off without pressing anything.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..forward();
    Timer(const Duration(milliseconds: 2500), _goNext);
  }

  Future<void> _goNext() async {
    final prefs = await SharedPreferences.getInstance();
    final consentGiven = prefs.getBool(AppKeys.consentGiven) ?? false;
    final usage = prefs.getBool('has_usage_access') ?? false;
    final accessibility = prefs.getBool('has_accessibility') ?? false;
    final battery = prefs.getBool('has_battery_optimization') ?? false;
    final hasSkippedLogin = prefs.getBool(AppKeys.hasSkippedLogin) ?? false;
    var isLoggedIn = false;
    try {
      isLoggedIn = Supabase.instance.client.auth.currentUser != null;
    } catch (_) {
      // Local sessions remain available if Supabase is not configured.
    }

    if (!mounted) return;

    if (!consentGiven) {
      context.go(AppRoutes.consent);
      return;
    }

    if (!isLoggedIn && !hasSkippedLogin) {
      context.go(AppRoutes.login);
      return;
    }

    if (kIsWeb) {
      context.go(AppRoutes.dashboard);
      return;
    }

    if (!(usage && accessibility && battery)) {
      context.go(AppRoutes.permissionWizard);
      return;
    }

    // MOB-3b — Session Resume on App Relaunch.
    // If the process was killed while a session was running the pref flag is
    // still true. Ask the viewmodel to reload the active row from SQLite and
    // restart the elapsed timer. It returns false and clears the stale flag if
    // the row is gone (e.g. the user force-stopped and cleared data).
    final sessionWasActive = prefs.getBool(AppKeys.sessionActive) ?? false;
    if (sessionWasActive) {
      final vm = ref.read(focusSessionProvider.notifier);
      final resumed = await vm.resumeSession();
      if (!mounted) return;
      if (resumed) {
        debugPrint(
            '[Splash] Session resumed — routing to focus session screen.');
        context.go(AppRoutes.focusSession);
        return;
      }
      debugPrint('[Splash] session_active was stale; going to dashboard.');
    }

    context.go(AppRoutes.dashboard);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: CurvedAnimation(
                  parent: _controller, curve: const Interval(0, 0.25)),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.8, end: 1).animate(
                  CurvedAnimation(
                      parent: _controller, curve: const Interval(0.25, 0.5)),
                ),
                child: const Icon(Icons.graphic_eq_rounded,
                    size: 80, color: AppColors.accentBlue),
              ),
            ),
            const SizedBox(height: 16),
            FadeTransition(
              opacity: CurvedAnimation(
                  parent: _controller, curve: const Interval(0.5, 0.75)),
              child: Text(
                'Focus Echo AI',
                style: AppTextStyles.displayLarge
                    .copyWith(color: AppColors.accentBlue),
              ),
            ),
            const SizedBox(height: 6),
            FadeTransition(
              opacity: CurvedAnimation(
                  parent: _controller, curve: const Interval(0.75, 1)),
              child: Text(
                'Take back your focus',
                style: AppTextStyles.bodyLarge
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
