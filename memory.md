# Focus Echo AI — Agent Memory

Last updated: 2026-04-29

## ✅ COMPLETED

### Phase 1–8: Original MVP Build
- Phase 1: pubspec.yaml, app_theme.dart, app_constants.dart, app_router.dart, models, launch.json
- Phase 2: consent_screen, consent_viewmodel, permission_wizard_screen, permission_wizard_viewmodel, permission_state, app_selector_screen, app_selector_viewmodel
- Phase 3: FocusDetectionService.kt, FocusAccessibilityService.kt, BootReceiver.kt, PermissionBridge.kt, BatteryBridge.kt, MainActivity.kt
- Phase 4: database_helper.dart, distraction_event_dao.dart, focus_session_dao.dart, sync_service.dart, supabase_service.dart
- Phase 5: focus_session_screen.dart, focus_session_viewmodel.dart, focus_session_state.dart, rule_engine.dart, distraction_alert_modal.dart
- Phase 6: dashboard_screen.dart, dashboard_viewmodel.dart, streaks_xp_screen.dart, streaks_xp_viewmodel.dart, analytics_screen.dart, analytics_viewmodel.dart
- Phase 7: splash_screen.dart, settings_screen.dart, settings_viewmodel.dart, main.dart
- Phase 8: requirements.txt, .env.example, main.py, schemas, rule_engine.py, scoring_service.py, API routes, ml_v2 README
- Backend deployment: Render service deployed and /health check passing
- GDPR deletion: Delete My Data implemented for cloud + local data wipe
- Privacy policy: finalized and linked in consent + settings screens

### APK Readiness Fixes (2026-04-26)
- Fixed package name mismatch in `build.gradle.kts`.
- Deleted duplicate `MainActivity.kt` stub in `com.example` package.
- Added `FOREGROUND_SERVICE_DATA_SYNC` permission to `AndroidManifest.xml`.
- Set `minSdk = 26` in `build.gradle.kts`.
- Fixed SharedPreferences key prefix mismatch (`flutter.` added) in all Kotlin files.
- Fixed invalid system notification icon reference in `FocusDetectionService.kt`.
- Fixed Splash route redirect loop in `app_router.dart`.
- Declared `foregroundServiceType="dataSync"` for Android 14+ compatibility.
- Added Android Firebase Messaging dependency in `android/app/build.gradle.kts`.
- Added native Firebase config probe channel (`focus_echo/firebase_config`) in `MainActivity.kt`.
- Added `firebase_config_service.dart` and startup guard to skip FCM init when resources missing.
- Updated DI container `app_dependencies.dart` with `isFirebaseConfigured` runtime flag.

### Production Hardening Audit (2026-04-29) — 35 files changed
- **B1 CRITICAL: Background execution failure** — Replaced broken MethodChannel in `FocusAccessibilityService.kt` with `DistractionEventQueue.kt` (thread-safe in-memory shared queue). Events now captured even when Flutter UI is killed.
- **B2 HIGH: Event loss when backgrounded** — Added `pendingEvents` buffer in `FocusDetectionService.kt`. Events buffered when EventSink is null. Flushed when Flutter reconnects via `MainActivity.onListen`.
- **B3 HIGH: onRecovery crash** — `firstWhere` → `firstOrNull` in `focus_session_viewmodel.dart`. Null event dismisses alert gracefully.
- **B4 CRITICAL: Hardcoded Supabase credentials** — Replaced with `String.fromEnvironment` in `app_constants.dart`. Override at build time via `--dart-define`.
- **S2 HIGH: Supabase JSON key mismatch** — `toJson()` (camelCase) → `toSqliteMap()` (snake_case) in `supabase_service.dart`. Fixes silent upsert failures.
- **S1 HIGH: No sync retry** — Added exponential backoff (3 attempts, 500ms/1s/2s) in `sync_service.dart`. Auth errors fail fast. Network errors abort immediately.
- **S4 MEDIUM: Nightly sync crash** — Added try-catch around Supabase init in `nightly_sync_worker.dart`. Returns `false` to trigger WorkManager retry.
- **P1 HIGH: 1s polling battery drain** — Polling interval 1s → 3s in `FocusDetectionService.kt`.
- **P2 MEDIUM: SharedPrefs read every tick** — Values cached in memory, refreshed every 5s via `CACHE_TTL_MS`.
- **P3 LOW: PageController leak** — Moved from `build()` to `State` class in `permission_wizard_screen.dart`.
- **D1 HIGH: QUERY_ALL_PACKAGES Play Store rejection** — Removed permission, added `<queries>` block for launcher apps in `AndroidManifest.xml`.
- **D2 MEDIUM: BootReceiver exported=true** — Set to `exported="false"`.
- **U1 HIGH: Hardcoded "Notion"** — Focus session now reads user-selected productive apps from SharedPreferences. Dropdown selector in `focus_session_screen.dart`.
- **U2 MEDIUM: No bottom navigation** — Added `ShellRoute` + `NavigationBar` in `app_router.dart` wrapping Dashboard, Analytics, Streaks, Settings.
- **A3 MEDIUM: Router stale redirect** — Added `refreshListenable` with `ValueNotifier` in `AppRouter`. `AppRouter.refresh()` called after consent and permission changes.
- **A4 LOW: Dead sync_queue code** — Removed sync_queue table creation and all writes from DAOs.
- **B5 LOW: Unreliable alert animation** — Replaced `TweenAnimationBuilder` with `AnimationController.repeat(reverse: true)` in `distraction_alert_modal.dart`.
- **D4 LOW: Insufficient system package filter** — Extended filter list in `FocusAccessibilityService` (launcher3, settings, nexuslauncher, packageinstaller).
- **U4 LOW: Package name instead of app label** — Added `getAppLabel()` in both Kotlin services using `PackageManager.getApplicationLabel()`.
- Added error state + pull-to-refresh to Dashboard, Analytics, and Streaks screens.
- Added ProGuard rules (`proguard-rules.pro`) for Firebase, Supabase, OkHttp, Kotlin serialization.
- Hardened `.gitignore` with `key.properties`, `google-services.json`, `*.jks`, `.env.*`.
- Created unit tests for `RuleEngine` (11 tests, all passing).
- Cleaned all analyzer warnings: 0 errors, 0 warnings (14 info-level `withOpacity` deprecation hints remaining).

## 🔴 PENDING (User Action Required)
- **Firebase Setup:** Run `flutterfire configure`, add `google-services.json` to `android/app/`.
- **Release Signing:** Generate keystore and create `key.properties`, configure in `build.gradle.kts`.
- **Rotate Supabase Key:** Old anon key is in git history. Rotate via Supabase dashboard.
- **Add RLS Policies:** Apply Row Level Security to all Supabase tables (SQL provided in production_fixes_report.md).
- **Set Production URLs:** Build with `--dart-define=BACKEND_URL=https://your-app.onrender.com`.
- **Real-Device Testing:** Test on Samsung, Xiaomi, and Pixel devices.

## 🏗️ ARCHITECTURE DECISIONS
- Foreground Service chosen over WorkManager for primary detection (START_STICKY for restart).
- SQLite write-first pattern for data persistence (offline-first).
- `DistractionEventQueue` (in-memory shared queue) for cross-service IPC — replaces broken MethodChannel.
- `pendingEvents` buffer for EventChannel sink-null scenarios — flush on reconnect.
- Exponential backoff retry for Supabase sync (3 attempts per record).
- Rule engine in Dart (client) AND Python (server) for offline/online consistency.
- Riverpod StateNotifier for immutable state management.
- go_router ShellRoute for persistent bottom navigation.
- `String.fromEnvironment` for build-time secret injection.
- 3-second polling with 5-second SharedPreferences cache TTL.

## 🚀 NEXT SPRINT (Sprint 3 — Intelligence)
- Complete remaining user-action pending items.
- Finalize signed release APK.
- Pilot rollout on 3 OEM devices.
- Collect 500 real user sessions for ML training.
- Train Random Forest risk classifier.
- A/B test ML vs rule engine.
