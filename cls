[33mcommit b8c910b4c14dfdef7eb7381ae447b0a538a1db0d[m[33m ([m[1;36mHEAD[m[33m -> [m[1;32mmain[m[33m)[m
Author: vignesh-DA <gogulavignesh9.com>
Date:   Wed Oct 21 20:24:04 2026 +0530

    feat(mob-3g): connect analytics screen to FastAPI backend - New BackendAnalyticsService (Dio client) for /api/v1/analytics/summary and /api/v1/analytics/risk-trend endpoints - AnalyticsViewModel loads local SQLite first (always fast), then fires parallel best-effort fetch to backend using Supabase JWT as Bearer token - Remote data merged into AnalyticsState: remoteFocusScoreAverage, remoteWeeklySessions, remoteTopApps, remoteRiskTrend, isRemoteLoaded - Analytics screen shows Backend Summary card, Synced Top Apps list, and 14-day Risk Trend sparkline when isRemoteLoaded=true - Guest/offline users see local-only data with no error shown - flutter analyze: No issues found (exit 0)

[33mcommit 9387cd90ab5eb8924a0f4952928db20f828e6908[m
Author: vignesh-DA <gogulavignesh9.com>
Date:   Wed Oct 21 20:12:49 2026 +0530

    feat(mob-3b,3c,3d): session resume on relaunch and streak logic - MOB-3b: resumeSession() reads active SQLite row, recomputes elapsed time, restarts timer. SplashScreen detects session_active pref and routes to /focus-session without user input. Stale flag auto-cleared if SQLite row is gone. - MOB-3c: _updateStreak() enforces min session length (1 min), same-day dedup, grace day window (streakGraceDays=1), resets if gap exceeded. - MOB-3d: AppKeys.cumulativeStreakDays increments per qualifying session (never resets), persisted in SharedPreferences, pushed to Supabase with consecutive streak. - Added AppKeys.lastSessionDate, AppKeys.cumulativeStreakDays, AppDurations.streakGraceDays constants. - flutter analyze: No issues found (exit 0)

[33mcommit 462911c0ff99264b3d93f7e92b0d18148afa088e[m
Author: vignesh-DA <gogulavignesh9.com>
Date:   Wed Oct 21 19:58:57 2026 +0530

    feat(mob-3e,3f): wire session completion XP and updateUserXP - MOB-3e: award sessionCompletionXp (50 XP) for sessions >= 1 min - MOB-3f: accumulate lifetime XP in SharedPreferences, call supabaseService.updateUserXP() fire-and-forget on session end - Replace magic literal 10 in onRecovery with AppXP.slowRecoveryXp - flutter analyze: No issues found (exit 0)

[33mcommit 96586e5e75dc6e65f8deb743e2bc176f655465b5[m
Author: vignesh-DA <gogulavignesh9.com>
Date:   Wed Oct 21 19:46:41 2026 +0530

    chore(extension): remove obsolete root background.js, content.js, test-phase1.ps1, and scratch dir

[33mcommit 2f54da7016084a4251d181b4b9dcfd11c0c82b32[m
Author: vignesh-DA <gogulavignesh9.com>
Date:   Sun Oct 18 02:41:07 2026 +0530

    docs(status): record EXT-1 live Chrome 9/9 verification
