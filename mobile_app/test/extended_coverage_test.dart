import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:focus_echo_ai/core/constants/app_constants.dart';
import 'package:focus_echo_ai/core/theme/app_theme.dart';
import 'package:focus_echo_ai/features/auth/login_viewmodel.dart';
import 'package:focus_echo_ai/services/focus_preferences_conflict.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('AppColors Constants (10 tests)', () {
    test('1. background color is dark navy', () {
      expect(AppColors.background, const Color(0xFF0A0E1A));
    });

    test('2. surface color is deep slate', () {
      expect(AppColors.surface, const Color(0xFF111827));
    });

    test('3. card color is midnight blue', () {
      expect(AppColors.card, const Color(0xFF1A2235));
    });

    test('4. accentBlue is vibrant electric cyan', () {
      expect(AppColors.accentBlue, const Color(0xFF00C2FF));
    });

    test('5. accentGreen is neon green', () {
      expect(AppColors.accentGreen, const Color(0xFF00FF88));
    });

    test('6. accentRed is vibrant red', () {
      expect(AppColors.accentRed, const Color(0xFFFF4444));
    });

    test('7. accentYellow is golden yellow', () {
      expect(AppColors.accentYellow, const Color(0xFFFFD700));
    });

    test('8. textPrimary is pure white', () {
      expect(AppColors.textPrimary, const Color(0xFFFFFFFF));
    });

    test('9. textSecondary is muted cool gray', () {
      expect(AppColors.textSecondary, const Color(0xFF8B9CB6));
    });

    test('10. border color is dark slate outline', () {
      expect(AppColors.border, const Color(0xFF1E2D45));
    });
  });

  group('AppTheme & Decorations (10 tests)', () {
    test('11. AppSpacing.xs is 4.0', () {
      expect(AppSpacing.xs, 4.0);
    });

    test('12. AppSpacing.sm is 8.0', () {
      expect(AppSpacing.sm, 8.0);
    });

    test('13. AppSpacing.md is 16.0', () {
      expect(AppSpacing.md, 16.0);
    });

    test('14. AppSpacing.lg is 24.0', () {
      expect(AppSpacing.lg, 24.0);
    });

    test('15. AppSpacing.xl is 32.0', () {
      expect(AppSpacing.xl, 32.0);
    });

    test('16. accentButton decoration uses rounded rectangle', () {
      final deco = AppDecorations.accentButton(AppColors.accentBlue);
      expect(deco.borderRadius, BorderRadius.circular(10));
    });

    test('17. accentButton decoration uses gradient', () {
      final deco = AppDecorations.accentButton(AppColors.accentBlue);
      expect(deco.gradient, isNotNull);
    });

    test('18. glassmorphismCard uses AppColors.border', () {
      final deco = AppDecorations.glassmorphismCard();
      expect(deco.border?.top.color, AppColors.border);
    });

    test('19. neonCard contains box shadows', () {
      final deco = AppDecorations.neonCard();
      expect(deco.boxShadow?.isNotEmpty, true);
    });

    test('20. AppSpacing constants are geometrically ascending', () {
      expect(AppSpacing.xs < AppSpacing.sm, true);
      expect(AppSpacing.sm < AppSpacing.md, true);
      expect(AppSpacing.md < AppSpacing.lg, true);
      expect(AppSpacing.lg < AppSpacing.xl, true);
      expect(AppSpacing.xl < AppSpacing.xxl, true);
    });
  });

  group('AppKeys & AppRoutes (10 tests)', () {
    test('21. AppKeys.userId is user_id', () {
      expect(AppKeys.userId, 'user_id');
    });

    test('22. AppKeys.consentGiven is consent_given', () {
      expect(AppKeys.consentGiven, 'consent_given');
    });

    test('23. AppKeys.hasSkippedLogin is has_skipped_login', () {
      expect(AppKeys.hasSkippedLogin, 'has_skipped_login');
    });

    test('24. AppKeys.productiveApps is productive_apps', () {
      expect(AppKeys.productiveApps, 'productive_apps');
    });

    test('25. AppKeys.webDistractingSites is web_distracting_sites', () {
      expect(AppKeys.webDistractingSites, 'web_distracting_sites');
    });

    test('26. AppRoutes.splash is /splash', () {
      expect(AppRoutes.splash, '/splash');
    });

    test('27. AppRoutes.login is /login', () {
      expect(AppRoutes.login, '/login');
    });

    test('28. AppRoutes.consent is /consent', () {
      expect(AppRoutes.consent, '/consent');
    });

    test('29. AppRoutes.dashboard is /dashboard', () {
      expect(AppRoutes.dashboard, '/dashboard');
    });

    test('30. AppRoutes.focusSession is /focus-session', () {
      expect(AppRoutes.focusSession, '/focus-session');
    });
  });

  group('LoginState & Config (10 tests)', () {
    test('31. default LoginState is not loading', () {
      const state = LoginState();
      expect(state.isLoading, false);
      expect(state.isSignUp, false);
      expect(state.errorMessage, isNull);
    });

    test('32. LoginState copyWith isLoading', () {
      const state = LoginState();
      final updated = state.copyWith(isLoading: true);
      expect(updated.isLoading, true);
      expect(updated.isSignUp, false);
    });

    test('33. LoginState copyWith isSignUp', () {
      const state = LoginState();
      final updated = state.copyWith(isSignUp: true);
      expect(updated.isSignUp, true);
      expect(updated.isLoading, false);
    });

    test('34. LoginState copyWith errorMessage', () {
      const state = LoginState();
      final updated = state.copyWith(errorMessage: 'Invalid credentials');
      expect(updated.errorMessage, 'Invalid credentials');
    });

    test('35. LoginState copyWith preserves unspecified fields', () {
      const state = LoginState(isLoading: true, isSignUp: true);
      final updated = state.copyWith(errorMessage: 'Test error');
      expect(updated.isLoading, true);
      expect(updated.isSignUp, true);
      expect(updated.errorMessage, 'Test error');
    });

    test('36. AppConfig.backendBaseUrl is non-empty string', () {
      expect(AppConfig.backendBaseUrl.isNotEmpty, true);
    });

    test('37. AppStrings.appName is Focus Echo AI', () {
      expect(AppStrings.appName, 'Focus Echo AI');
    });

    test('38. AppStrings.distractionDetected is defined', () {
      expect(AppStrings.distractionDetected.contains('focus check'), true);
    });

    test('39. AppRoutes.settings is /settings', () {
      expect(AppRoutes.settings, '/settings');
    });

    test('40. AppRoutes.analytics is /analytics', () {
      expect(AppRoutes.analytics, '/analytics');
    });
  });

  group('Focus Preferences & Site Snapshot Rules (10 tests)', () {
    final now = DateTime.utc(2026, 11, 2, 14);

    test('41. local edit 10s newer than remote wins', () {
      expect(
        resolveFocusPreferenceConflict(
          localUpdatedAt: now.add(const Duration(seconds: 10)),
          remoteUpdatedAt: now,
        ),
        FocusPreferenceWinner.local,
      );
    });

    test('42. remote edit 10s newer than local wins', () {
      expect(
        resolveFocusPreferenceConflict(
          localUpdatedAt: now.subtract(const Duration(seconds: 10)),
          remoteUpdatedAt: now,
        ),
        FocusPreferenceWinner.remote,
      );
    });

    test('43. identical millisecond timestamps favor remote server truth', () {
      expect(
        resolveFocusPreferenceConflict(
          localUpdatedAt: now,
          remoteUpdatedAt: now,
        ),
        FocusPreferenceWinner.remote,
      );
    });

    test('44. site snapshot creates independent clone', () {
      final original = ['youtube.com', 'twitter.com', 'reddit.com'];
      final snapshot = createSessionSiteSnapshot(original);
      snapshot.add('tiktok.com');
      expect(original.length, 3);
      expect(snapshot.length, 4);
    });

    test('45. empty site snapshot produces empty list', () {
      final snapshot = createSessionSiteSnapshot([]);
      expect(snapshot.isEmpty, true);
    });

    test('46. modifying snapshot does not mutate source', () {
      final original = ['instagram.com'];
      final snapshot = createSessionSiteSnapshot(original);
      snapshot.clear();
      expect(original.isNotEmpty, true);
      expect(snapshot.isEmpty, true);
    });

    test('47. AppDurations.recoveryCountdownSeconds is 10', () {
      expect(AppDurations.recoveryCountdownSeconds, 10);
    });

    test('48. AppDurations.transitionThresholdMs is 15000', () {
      expect(AppDurations.transitionThresholdMs, 15000);
    });

    test('49. AppRoutes.appLimits is /app-limits', () {
      expect(AppRoutes.appLimits, '/app-limits');
    });

    test('50. AppRoutes.permissionWizard is /permission-wizard', () {
      expect(AppRoutes.permissionWizard, '/permission-wizard');
    });
  });
}
