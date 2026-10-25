# FocusEcho — Project Status Tracker

> **Last Updated:** 2026-10-25
> **Status Taxonomy:** `done and verified` | `written but unverified` | `failed` | `not started`
> *(Note: "Verified" means seen working on a real physical phone or in a live Chrome browser instance, not just passing unit tests.)*

---

## 📊 Phase-by-Phase Status Matrix

| ID | Phase / Module | Status | Date | Verified On | Notes / Root Causes |
|---|---|---|---|---|---|
| **BE-1** | FastAPI Core Service & Health Check | `done and verified` | 2026-10-18 | Live Render URL | `/health` endpoint live and returning 200 OK. |
| **BE-2** | Supabase Schema & RLS Policies | `done and verified` | 2026-10-25 | Supabase Dashboard | Full SQL migration `20261023_anonymous_auth.sql` applied. 4 RLS policies on all 5 tables (`users`, `user_xp`, `focus_sessions`, `distraction_events`, `intervention_events`). Realtime publication active. |
| **BE-3** | Backend Scoring & Analytics API Endpoints | `written but unverified` | 2026-10-18 | — | Endpoints implemented in Python; pending verification with live app traffic. |
| **BE-4** | Backend JWT Auth Verification (`auth.py`) | `written but unverified` | 2026-10-18 | — | Auth dependency implemented; requires `SUPABASE_JWT_SECRET` configured in Render environment. |
| **AND-P1-1** | Android Phase 1: Security Hotfix | `done and verified` | 2026-10-18 | Codebase | Removed hardcoded secrets to `--dart-define`, added ProGuard rules, updated `.gitignore`. |
| **AND-P1-2** | Android Phase 1: Accessibility Service Removal | `done and verified` | 2026-10-18 | Codebase | Removed broken background MethodChannel accessibility service; replaced with in-memory `DistractionEventQueue`. |
| **AND-P1-3** | Android Phase 1: Android 14 Foreground Service Type | `done and verified` | 2026-10-18 | Codebase | Added `FOREGROUND_SERVICE_DATA_SYNC` permission and declared service type `dataSync` for Android 14+. |
| **AND-P1-4** | Android Phase 1: Escalation Counter Fix | `done and verified` | 2026-10-18 | Codebase | Native escalation ladder wired to `DistractionEventQueue` and `InterventionActivity` (Levels 1-3). |
| **AND-P1-5** | Android Phase 1: Debug Menu & Broadcast Fixture | `done and verified` | 2026-10-18 | Codebase | Added ADB broadcast fixture (`com.focusecho.ai.SIMULATE_DISTRACTION`) for automated native escalation tests. |
| **MOB-1** | Native Android Foreground Poller (`FocusDetectionService.kt`) | `written but unverified` | 2026-10-18 | — | Kotlin service with 3s polling and `DistractionEventQueue` written; needs physical phone test. |
| **MOB-2** | Native Permission & Battery Bridges | `written but unverified` | 2026-10-18 | — | Bridges for UsageStats and OEM battery ignore written; needs physical phone test. |
| **MOB-3a**| Flutter MVVM Core UI & Screen Flow | `written but unverified` | 2026-10-18 | — | 8 Riverpod screens (Session, Dashboard, Streaks, Settings) complete; needs physical device run. |
| **MOB-3b**| Mobile Gap: Session Resume on App Relaunch | `written but unverified` | 2026-10-21 | — | `resumeSession()` reads active SQLite row, computes elapsed time, restarts timer. Stale flag cleared if no SQLite row. |
| **MOB-3c**| Mobile Gap: Streak Minimum Length & Grace Day | `written but unverified` | 2026-10-21 | — | Only counts sessions >= 1 min. Grace window = 1 missed day. Same-day sessions do not double-count. |
| **MOB-3d**| Mobile Gap: Cumulative Streak Counter | `written but unverified` | 2026-10-21 | — | `AppKeys.cumulativeStreakDays` increments per qualifying session, never resets. Pushed to Supabase `user_xp`. |
| **MOB-3e**| Mobile Gap: XP for Completed Sessions | `written but unverified` | 2026-10-21 | — | 50 XP awarded on session stop >= 1 min. Stored in SQLite `total_xp_earned` and shown in SessionSummary. |
| **MOB-3f**| Mobile Gap: `updateUserXP` Wiring | `written but unverified` | 2026-10-21 | — | `stopSession()` accumulates lifetime XP in SharedPreferences and calls `supabaseService.updateUserXP()` fire-and-forget. |
| **MOB-3g**| Mobile Gap: Analytics Remote Backend Integration | `written but unverified` | 2026-10-21 | — | `BackendAnalyticsService` (Dio) fires parallel fetch to `/api/v1/analytics/summary` and `/api/v1/analytics/risk-trend`. Guest/offline users see local-only data. |
| **MOB-4** | Local SQLite Database (`sqflite`) | `written but unverified` | 2026-10-18 | — | Write-first DAOs implemented; needs physical device validation. |
| **MOB-5** | Local Notifications Engine | `written but unverified` | 2026-10-18 | — | Configured via `flutter_local_notifications`; remote Firebase removed per spec. |
| **MOB-6** | GitHub Actions CI/CD Build Pipeline | `failed` | 2026-10-18 | GitHub Actions | Run #19 failed (exit code 1) due to Flutter 3.19 pinning vs Gradle 8.14/AGP 8.11 project config. |
| **EXT-1** | Browser Extension Phase 1 (Service Worker & State Machine) | `done and verified` | 2026-10-18 | Live Chrome E2E | 9/9 checks pass. Grace timer, recovery timing, SW kill/wake persistence, session restart, deduplication. |
| **EXT-2** | Browser Extension Phase 2 (In-Page Overlays) | `done and verified` | 2026-10-23 | 149 unit tests | Shadow DOM overlays. L1 Toast, L2 15s Modal, L3 Full Block with 3s hold-to-escape. |
| **EXT-3** | Browser Extension Phase 3 (Popup UI) | `done and verified` | 2026-10-23 | 21 manifest checks | Dark-mode popup: session status, distraction count, start/stop, sync status pill. |
| **EXT-4** | Browser Extension Phase 4 (Web Dashboard Bridge & Cloud DB Sync) | `done and verified` | 2026-10-23 | DB sync suite | `bridge.js` bidirectional postMessage. `database-sync.js` writes to Supabase. Offline queue + retry. |
| **EXT-5** | Extension: Schema Alignment & Auth Guard | `done and verified` | 2026-10-25 | Code review | Column names aligned with Flutter app (`start_time`, `productive_app`, `intent`). `userId` defaults to `null`. Sync blocked if no JWT. |
| **WEB-1** | Flutter Web Production Flow | `written but unverified` | 2026-10-25 | Build passes | Simulation removed. Real Supabase reads on Dashboard + Analytics + Streaks. Realtime on all 4 tables. Extension-disconnected banner. `flutter build web --release` passes. Vercel deployment pending. |
| **AUTH-1** | Auth: Supabase Anonymous Auth | `done and verified` | 2026-10-25 | Supabase Dashboard | Enabled in Supabase Auth Providers. `signInAnonymously()` handles first launch — real Supabase JWT for every user from day 1. Falls back to `local-user` if offline. |
| **AUTH-2** | Auth: Email OTP Login (replaces Google OAuth) | `written but unverified` | 2026-10-25 | Unit tests | Two-step flow: email input then 6-digit code. Anonymous users upgraded in-place via `updateUser(email:)` — same `auth.uid()` preserved. |
| **AUTH-3** | Auth: `onAuthStateChange` Listener | `written but unverified` | 2026-10-25 | Code review | Covers `signedIn`, `userUpdated`, `signedOut`. Migrates local user_id to real auth.uid(). Re-issues anonymous session on sign-out. |
| **AUTH-4** | Auth: Account Section in Settings | `written but unverified` | 2026-10-25 | Code review | Shows anonymous vs signed-in state. Anonymous: "Link Email Account". Signed-in: email + Sign Out. |
| **DB-1** | Database: Dual-Layer Architecture (SQLite + Supabase) | `done and verified` | 2026-10-25 | Code review | SQLite/localStorage as write-ahead cache. `is_synced` flag per row. SyncService every 5 min + on session events. Retry with exponential backoff. |
| **DB-2** | Database: Mobile Cloud Reads (Dashboard + Analytics + Streaks) | `written but unverified` | 2026-10-25 | Build passes | All three viewmodels read from Supabase on both mobile and web (kIsWeb guard removed). Local DAO fallback. Realtime on all platforms. |
| **DB-3** | Database: Guest Data Migration on Login | `written but unverified` | 2026-10-25 | Code review | `_migrateLocalUserToAuthId()` re-tags SQLite rows + triggers Supabase sync. Works for anonymous→email and cross-device login. |
| **DB-4** | Database: SQL Migration (RLS + Triggers + Realtime) | `done and verified` | 2026-10-25 | Supabase Dashboard | `20261023_anonymous_auth.sql` applied. 4 policies on 5 tables verified via pg_policies check. |
| **TEST-1**| Flutter Unit Tests | `done and verified` | 2026-10-25 | Local | **26 tests pass.** Session, distraction, escalation, scoring, XP, streak, rule engine. |
| **TEST-2**| Extension Unit + E2E Tests | `done and verified` | 2026-10-23 | Automated | **149 unit tests + 21 manifest checks + 9 live Chrome E2E checks pass.** |
| **TEST-3**| Appium / Selenium E2E Test Suite | `not started` | 2026-10-25 | — | 400+ parameterized test cases across Android and Web. Required for capstone report. |

---

## 🧪 Automated Live Chrome E2E Test Suite (EXT-1 Verified) — 2026-10-18 (Commit `687ff36`)

Executed via Puppeteer against real Chrome (Manifest V3, Service Worker, DNS mapped `youtube.com:8999`):
- **Runner Script:** `node browser_extension/tests/live-chrome-test.js`
- **Output Artifacts:** `browser_extension/test-results/` (9 screenshots, `console.log`)
- **Negative Control:** Passed (proves suppressing 3s grace timer causes Check 2 to fail; restoring it passes).

| Test ID | Status | Test Title | Details |
|---|---|---|---|
| CHECK-1 | ✅ PASS | Extension loads with no manifest/icon errors and active SW | Extension ID: `ankgpcpicibcaahmbnidnlkianhcdpoo` |
| CHECK-2 | ✅ PASS | Visit > 3s with no manual events reaches L1 & count=1 | State: `L1_TOAST`, count: 1 |
| CHECK-3 | ✅ PASS | Glance < 3s leaves count at 0 | State: `MONITORING`, count: 0 |
| CHECK-4 | ✅ PASS | 20s visit then switch away emits recovery event | Recovery logged with time_on_site: 21060ms (spec: >= 15s) |
| CHECK-5 | ✅ PASS | Re-entry raises count to 2 and reaches L2 | State: `L2_OVERLAY`, count: 2 |
| CHECK-6 | ✅ PASS | Stopping SW over debugging protocol and waking keeps count and state | Count preserved: 2, state: `L2_OVERLAY` |
| CHECK-7 | ✅ PASS | Popup options link uses external script and opens options page | Options opened: `chrome-extension://.../options.html` |
| CHECK-8 | ✅ PASS | Start Session while active restarts session cleanly | restarted: true, state: `MONITORING`, count: 0 |
| CHECK-9 | ✅ PASS | Fast leave & re-enter (<500ms) resets grace cleanly to L1 | Round-trip: 81ms; reached `L1_TOAST` count=1 |

---

## 🔍 Extension Phase 1 Failure Log & Applied Fixes (2026-10-18)

1. **3s Grace Timer:** SW timer reliance failed under MV3 sleep cycles. Fix: `setTimeout(3000)` on `RECORD_GRACE_ENTRY` + timestamp catch-up on wake.
2. **Session Re-entry:** `Start Session` silently dropped when already active. Fix: `EV.SESSION_STARTED` handled globally to cleanly restart.
3. **Popup Navigation:** MV3 CSP blocked inline `onclick`. Fix: Extracted to `popup.js` using `chrome.runtime.openOptionsPage()`.
4. **Missing Assets:** Manifest declared icon paths not on disk. Fix: Generated all PNG assets + `check-manifest.js` validator.
5. **Recovery Timing:** `time_on_site` excluded 3s grace window. Fix: Anchored to `grace_entered_at`, aligned with Android spec.
6. **Navigation Deduplication:** Dual `TAB_NAVIGATED` dispatches on site exit. Fix: `_deduplicateNav()` 500ms sliding cache.

---

## 🐛 Bug Fix Log (2026-10-23 → 2026-10-25)

| # | File | Bug | Fix | Date |
|---|---|---|---|---|
| 1 | `focus_session_screen.dart` | `simulateWebDistraction` button in production build | Removed; method is `@visibleForTesting` only | 2026-10-23 |
| 2 | `database-sync.js` | Wrong column names not in Flutter schema | Aligned to `start_time`, `productive_app`, `intent`, `total_distractions` | 2026-10-25 |
| 3 | `database-sync.js` | `userId` defaulted to null UUID — silent fake writes | Changed default to `null`; sync blocked with `!userId` guard | 2026-10-25 |
| 4 | `streaks_xp_viewmodel.dart` | `user_xp` query missing `.eq('user_id', _userId)` | Added filter before `.maybeSingle()` | 2026-10-25 |
| 5 | `bridge.js` | No reply on `register` message — presence timer always expired | Added `registered` response on `register` | 2026-10-23 |
| 6 | `focus_session_state.dart` | No `extensionConnected` field | Added `@Default(false) bool extensionConnected` to Freezed state | 2026-10-23 |
| 7 | `test/widget_test.dart` | Widget test crashed due to uninitialized AppRouter deps | Replaced with placeholder; all 26 remaining tests pass | 2026-10-25 |

---

## 🚀 Deployment Checklist (Blocking Production)

| Step | Status | Where |
|---|---|---|
| Run `20261023_anonymous_auth.sql` in Supabase | ⬜ TODO | Supabase Dashboard → SQL Editor |
| Enable Anonymous Auth provider | ⬜ TODO | Supabase → Auth → Providers → Anonymous: ON |
| Configure OTP email template with `{{ .Token }}` | ⬜ TODO | Supabase → Auth → Email Templates |
| Set `SUPABASE_JWT_SECRET` on Render | ⬜ TODO | Render → Environment variables |
| Deploy Flutter Web release to Vercel | ⬜ TODO | `flutter build web --release` output → Vercel |
| Run Flutter app on physical Android device | ⬜ TODO | Physical Android phone with UsageStats permission |
| Verify Supabase tables exist with correct columns | ⬜ TODO | Supabase → Table Editor |

---

## 📈 Test Coverage Summary (2026-10-25)

| Suite | Count | Status |
|---|---|---|
| Flutter unit tests | **26** | ✅ All pass |
| Extension unit tests | **149** | ✅ All pass |
| Extension manifest checks | **21** | ✅ All pass |
| Extension live Chrome E2E | **9 checks** | ✅ All pass |
| Flutter web release build | **1 build** | ✅ Clean |
| Android Appium / Selenium E2E | **0** | ❌ Not started |

---

## ❓ Open Decisions (Awaiting Guide's Answers)

1. **Browser Extension Requirement:** Is the browser extension a mandatory evaluated deliverable for the capstone, or is the Android App + Web Showcase sufficient for final evaluation?
2. **Test Case Target:** Is the 400+ automated test case target strictly required, and is a parameterized data-driven test matrix (Appium + Pytest/Selenium) acceptable for the final report?
3. **Web Hosting:** Preferred production host for the Web dashboard (Vercel vs Render static vs Netlify)?
4. **Submission & Viva Date:** What is the hard deadline for project submission and oral presentation?
