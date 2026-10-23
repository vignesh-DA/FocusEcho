class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const consent = '/consent';
  static const permissionWizard = '/permission-wizard';
  static const batteryOptimization = '/battery-optimization';
  static const appSelector = '/app-selector';
  static const dashboard = '/dashboard';
  static const focusSession = '/focus-session';
  static const distractionAlert = '/distraction-alert';
  static const analytics = '/analytics';
  static const streaksXp = '/streaks-xp';
  static const settings = '/settings';
  static const appLimits = '/app-limits';
}

class AppKeys {
  static const sessionActive = 'session_active';
  static const productiveApps = 'productive_apps';
  static const distractingApps = 'distracting_apps';
  static const appTimeLimitsSeconds = 'app_time_limits_seconds';
  static const webDistractingSites = 'web_distracting_sites';
  static const userId = 'user_id';
  static const xpTotal = 'xp_total';
  static const streakDays = 'streak_days';
  /// Lifetime total of all streak days ever earned (MOB-3d).
  static const cumulativeStreakDays = 'cumulative_streak_days';
  /// ISO-8601 date (yyyy-MM-dd) of the last day a session was completed.
  /// Used by streak logic to detect consecutive-day activity (MOB-3c).
  static const lastSessionDate = 'last_session_date';
  static const consentGiven = 'consent_given';
  static const syncEnabled = 'sync_enabled';
  static const localOnlyMode = 'local_only_mode';
  static const analyticsEnabled = 'analytics_enabled';
  static const hasSkippedLogin = 'has_skipped_login';
  static const sessionIntent = 'session_intent';
  static const crossSurfaceNudges = 'cross_surface_nudges';
}

class AppChannels {
  static const permissions = 'focus_echo/permissions';
  static const battery = 'focus_echo/battery';
  static const appSwitch = 'focus_echo/app_switch';
  static const session = 'focus_echo/session';
  static const distractionStream = 'focus_echo/distraction_stream';
}

class AppDurations {
  static const recoveryCountdownSeconds = 10;
  static const syncRetryIntervalMinutes = 5;
  static const sessionCheckIntervalSeconds = 1;
  static const gracePeriodMs = 3000;
  static const transitionThresholdMs = 15000;
  static const unknownThresholdMs = 10000;
  static const notificationGraceMs = 30000;
  static const screenOnGraceMs = 5000;
  static const debounceMs = 500;
  /// Number of missed days allowed before a streak resets (MOB-3c grace day).
  /// 1 = the user may miss exactly one calendar day and still keep their streak.
  static const streakGraceDays = 1;
}

/// Supabase + backend config — ALL values must be injected at build time:
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=<anon-key> \
///     --dart-define=BACKEND_URL=https://<render-host>
///
/// See dart_defines.example in the repo root for a template.
/// Never hard-code credentials here — the file is checked into git and the
/// compiled string is visible in the decompiled APK.
class AppConfig {
  /// Supabase project URL. Required — app will throw at startup if empty.
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Supabase anon key. Required — app will throw at startup if empty.
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// FastAPI backend base URL.
  /// Default: Android emulator localhost. Override for physical device / CI.
  static const backendBaseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
}

class AppStrings {
  static const appName = 'Focus Echo AI';
  static const appSubtitle = 'Your intelligent focus companion';
  static const distractionDetected = "Heads up — quick focus check";
  static const iAmBack = "I'm Back! 🎯";
  static const endSession = 'End Session';
  static const startSession = 'Start Focus Session →';
  static const level1 = 'Focus Rookie';
  static const level2 = 'Consistency Pro';
  static const level3 = 'Flow Master';
  static const level4 = 'Zen Monk';
}

class AppXP {
  static const level1Max = 499;
  static const level2Min = 500;
  static const level2Max = 1499;
  static const level3Min = 1500;
  static const level3Max = 3499;
  static const level4Min = 3500;
  /// XP for recovering from a distraction within [AppRiskThresholds.mediumRecoverySeconds].
  static const recoveryXp = 25;
  /// XP for recovering after [AppRiskThresholds.mediumRecoverySeconds] (slower recovery).
  static const slowRecoveryXp = 10;
  static const failurePenalty = -10;
  static const streakBonus7Days = 100;
  /// Base XP awarded when a session is stopped cleanly (MOB-3e).
  static const sessionCompletionXp = 50;
  /// Minimum session duration (minutes) before base completion XP is awarded.
  /// Guards against 1-second accidental sessions earning points (MOB-3e).
  static const minSessionMinutesForXp = 1;
}

class AppRiskThresholds {
  static const highRiskEventsIn30Min = 3;
  static const criticalRepeatSameApp = 2;
  static const mediumRecoverySeconds = 10;
  static const recentWindowMinutes = 30;
}
