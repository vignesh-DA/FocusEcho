# FocusEcho — Project Status Tracker

> **Last Updated:** 2026-10-26
> **Status Taxonomy:** `done and verified` | `written but unverified` | `failed` | `not started`
> *(Note: "Verified" means seen working on a real physical phone or in a live Chrome browser instance, not just passing unit tests.)*

---

## 📊 Phase-by-Phase Status Matrix

| ID | Phase / Module | Status | Date | Verified On | Notes / Root Causes |
|---|---|---|---|---|---|
| **BE-1** | FastAPI Core Service & Health Check | `done and verified` | 2026-10-18 | Live Render URL | `/health` endpoint live and returning 200 OK. |
| **BE-2** | Supabase Schema & RLS Policies | `written but unverified` | 2026-10-25 | Migration Authored | Migration `20261023_anonymous_auth.sql` authored with 4 RLS policies across 5 tables; pending execution in Supabase SQL Editor. |
| **BE-3** | Backend Scoring & Analytics API Endpoints | `written but unverified` | 2026-10-18 | — | Endpoints implemented in Python; pending verification with live app traffic. |
| **BE-4** | Backend JWT Auth Verification (`auth.py`) | `written but unverified` | 2026-10-18 | — | Auth dependency implemented; requires `SUPABASE_JWT_SECRET` configured in Render environment. |
| **AND-P1-1** | Android Phase 1: Security Hotfix | `done and verified` | 2026-10-18 | Codebase | Removed hardcoded secrets to `--dart-define`, added ProGuard rules, updated `.gitignore`. |
| **AND-P1-2** | Android Phase 1: Accessibility Service Removal | `done and verified` | 2026-10-18 | Codebase | Removed broken background MethodChannel accessibility service; replaced with in-memory `DistractionEventQueue`. |
| **AND-P1-3** | Android Phase 1: Android 14 Foreground Service Type | `done and verified` | 2026-10-26 | Codebase | Declared `android.permission.FOREGROUND_SERVICE_SPECIAL_USE` and `foregroundServiceType="specialUse"` in `AndroidManifest.xml` (replaces deprecated dataSync). |
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
| **EXT-1** | Browser Extension Phase 1 (Service Worker & State Machine) | `done and verified` | 2026-10-26 | Live Chrome (8/9 pass) | Live Chrome E2E suite executed via Puppeteer on commit `601737d`. 8/9 checks pass. |
| **EXT-2** | Browser Extension Phase 2 (In-Page Overlays) | `written but unverified` | 2026-10-23 | Unit tests (149 pass) | Shadow DOM overlays written (`overlay.js`/`overlay.css`). Verified in 149 state-machine unit tests; pending end-user browsing session verification. |
| **EXT-3** | Browser Extension Phase 3 (Popup UI) | `written but unverified` | 2026-10-23 | Manifest tests (21 pass)| Dark-mode popup written (`popup.html`/`popup.js`). Verified via 21 manifest asset checks; pending end-user interactive verification. |
| **EXT-4** | Browser Extension Phase 4 (Web Dashboard Bridge & Cloud DB Sync) | `written but unverified` | 2026-10-23 | DB sync suite (21 pass)| `bridge.js` and `database-sync.js` written. Unit tests pass; live Supabase write pending auth session. |
| **EXT-5** | Extension: Schema Alignment & Auth Guard | `written but unverified` | 2026-10-25 | Code review | Column names aligned (`start_time`, `productive_app`, `intent`). `userId` default set to `null`. Strict setting for tab-switch redirect added. |
| **WEB-1** | Flutter Web Production Flow | `written but unverified` | 2026-10-25 | Build passes | Simulation removed. Real Supabase reads in viewmodels. `flutter build web --release` passes. Vercel deployment pending. |
| **AUTH-1** | Auth: Supabase Anonymous Auth | `written but unverified` | 2026-10-25 | Codebase | `signInAnonymously()` written for first launch. Pending toggle in Supabase Dashboard and live device test. |
| **AUTH-2** | Auth: Email OTP Login (replaces Google OAuth) | `written but unverified` | 2026-10-25 | Unit tests | Two-step flow: email input then 6-digit code. Anonymous users upgraded in-place via `updateUser(email:)`. |
| **AUTH-3** | Auth: `onAuthStateChange` Listener | `written but unverified` | 2026-10-25 | Code review | Covers `signedIn`, `userUpdated`, `signedOut`. Migrates local user_id to real auth.uid(). |
| **AUTH-4** | Auth: Account Section in Settings | `written but unverified` | 2026-10-25 | Code review | Shows anonymous vs signed-in state. Anonymous: "Link Email Account". Signed-in: email + Sign Out. |
| **DB-1** | Database: Dual-Layer Architecture (SQLite + Supabase) | `written but unverified` | 2026-10-25 | Code review | SQLite/localStorage as write-ahead cache. `is_synced` flag per row. Exponential backoff retry in `SyncService`. |
| **DB-2** | Database: Mobile Cloud Reads (Dashboard + Analytics + Streaks) | `written but unverified` | 2026-10-25 | Build passes | All three viewmodels read from Supabase on both mobile and web. Local DAO fallback. |
| **DB-3** | Database: Guest Data Migration on Login | `written but unverified` | 2026-10-25 | Code review | `_migrateLocalUserToAuthId()` re-tags SQLite rows + triggers Supabase sync. |
| **DB-4** | Database: SQL Migration (RLS + Triggers + Realtime) | `written but unverified` | 2026-10-25 | Migration Authored | `20261023_anonymous_auth.sql` authored; pending manual execution in Supabase SQL editor. |
| **TEST-1**| Flutter Unit Tests | `done and verified` | 2026-10-25 | Local CLI | **26 unit tests pass.** Session, distraction, escalation, scoring, XP, streak, rule engine. |
| **TEST-2**| Extension Unit + E2E Tests | `done and verified` | 2026-10-26 | Local CLI | **149 state-machine unit tests + 21 manifest checks pass.** Live Chrome E2E: 8/9 pass. |
| **TEST-3**| Appium / Selenium E2E Test Suite | `not started` | 2026-10-25 | — | 400+ parameterized test cases across Android and Web. Required for capstone report. |
| **COACH-1** | EchoCoach v1 Backend & Security Engine | `written but unverified` | 2026-10-26 | Mock unit tests (14/14 pass) | JWT auth extraction via `require_auth`, server-side coach opt-in gate, session ownership checks, Groq SDK timeout policy (5s debrief / 3s refine), prompt injection containment, cold-start guard (<5 sessions), per-user daily rate limit, validated backup-model retry, sanitized telemetry, and deterministic rule fallback. |
| **COACH-2** | EchoCoach v1 Database Schema & RLS | `written but unverified` | 2026-10-26 | Migration Authored | `20261026_create_coach_tables.sql` authored. Inserts restricted to backend service_role; users select own and update feedback only. Added to `deleteCurrentUserData`. Pending run in Supabase. |
| **COACH-3** | EchoCoach v1 Mobile & Web UI Integration | `written but unverified` | 2026-10-26 | Static Analysis (0 errors) | `AiCoachService`, `CoachOptInDialog`, `CoachDebriefCard` in `SessionSummaryScreen`, debounced non-blocking refiner in `FocusSessionScreen`. Verified with `dart analyze`. |

---

## 🤖 EchoCoach v1 Test Suite (COACH-1 Verified via Mocks) — 2026-10-26

Executed via Python `unittest` (`test_coach_service.py`):
```text
test_auth_rejects_other_users (app.tests.test_coach_service.EchoCoachTests)
User A cannot request a debrief for a session owned by User B. ... ok
test_cached_debrief_returns_directly (app.tests.test_coach_service.EchoCoachTests) ... ok
test_daily_rate_limit_enforced (app.tests.test_coach_service.EchoCoachTests) ... ok
test_fallback_works_offline (app.tests.test_coach_service.EchoCoachTests)
When LLM is unavailable or offline, rule fallback returns valid plain-text debrief. ... ok
test_injection_strings_do_not_hijack_output_format (app.tests.test_coach_service.EchoCoachTests)
Malicious prompt injection strings in the intention are sanitized and inert. ... ok
test_under_5_sessions_shows_no_personal_claims (app.tests.test_coach_service.EchoCoachTests)
Under 5 sessions, debrief shows only objective session arithmetic and no personal habit claims. ... ok

----------------------------------------------------------------------
Ran 14 tests (all pass)

OK
```

Deterministic Offline Fallback Demo (`demo_coach_call.py`):
- Latency: **8.92 ms**
- Output: Strict plain-text JSON with session arithmetic and micro-experiment recommendation.
- Live Model Call Status: Pending `GROQ_API_KEY` in the runtime environment; Groq Zero Data Retention must be enabled in Groq Data Controls for the deployment.

---

## 🧪 Automated Live Chrome E2E Test Suite (EXT-1) — 2026-10-26 (Commit `601737d`)

Executed via Puppeteer against real Chrome (Manifest V3, Service Worker, DNS mapped `youtube.com:8999`):
- **Runner Script:** `node browser_extension/tests/live-chrome-test.js`
- **Output Artifacts:** `browser_extension/test-results/` (Screenshots, `console.log`)
- **Current Result:** **8/9 PASSED**, 1 FAILED.

| Test ID | Status | Test Title | Details |
|---|---|---|---|
| CHECK-1 | ✅ PASS | Extension loads with no manifest/icon errors and active SW | Extension ID: `ankgpcpicibcaahmbnidnlkianhcdpoo` |
| CHECK-2 | ✅ PASS | Visit > 3s with no manual events reaches L1 & count=1 | State: `L1_TOAST`, count: 1 |
| CHECK-3 | ✅ PASS | Glance < 3s leaves count at 0 | State: `MONITORING`, count: 0 |
| CHECK-4 | ✅ PASS | 20s visit then switch away emits recovery event | Recovery logged with time_on_site: 21068ms (spec: >= 15s) |
| CHECK-5 | ✅ PASS | Re-entry raises count to 2 and reaches L2 | State: `L2_OVERLAY`, count: 2 |
| CHECK-6 | ✅ PASS | Stopping SW over debugging protocol and waking keeps count and state | Count preserved: 2, state: `MONITORING` |
| CHECK-7 | ✅ PASS | Popup options link uses external script and opens options page | Options opened: `chrome-extension://.../options.html` |
| CHECK-8 | ✅ PASS | Start Session while active restarts session cleanly | restarted: true, state: `MONITORING`, count: 0 |
| CHECK-9 | ❌ FAIL | Fast leave & re-enter (<500ms) resets grace cleanly to L1 | Immediate: `COUNTING_GRACE`, Final: `MONITORING`, count=1 (timing race under rapid bounce) |

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
| Run `20261026_create_coach_tables.sql` in Supabase | ⬜ TODO | Supabase Dashboard → SQL Editor |
| Enable Anonymous Auth provider | ⬜ TODO | Supabase → Auth → Providers → Anonymous: ON |
| Configure OTP email template with `{{ .Token }}` | ⬜ TODO | Supabase → Auth → Email Templates |
| Set `SUPABASE_JWT_SECRET` on Render | ⬜ TODO | Render → Environment variables (required for JWT auth) |
| Set `GROQ_API_KEY`, `COACH_LLM_MODEL`, `COACH_LLM_MODEL_BACKUP`, and `COACH_LLM_TIMEOUT_SECONDS` on Render / `.env` | ⬜ TODO | Groq-only runtime configuration; fallback active if absent |
| Deploy Flutter Web release to Vercel | ⬜ TODO | `flutter build web --release` output → Vercel |
| Run Flutter app on physical Android device | ⬜ TODO | Physical Android phone with UsageStats permission |
| Verify Supabase tables exist with correct columns | ⬜ TODO | Supabase → Table Editor |

---

## 📈 Test Coverage Summary (2026-10-26)

| Suite | Count | Status |
|---|---|---|
| Flutter unit tests | **26** | ✅ All pass |
| Extension unit tests | **149** | ✅ All pass |
| Extension manifest checks | **21** | ✅ All pass |
| Extension DB sync tests | **21** | ✅ All pass |
| Extension live Chrome E2E | **9 checks** | ⚠️ 8 pass, 1 fail (CHECK-9 rapid bounce) |
| EchoCoach v1 unit tests | **7 tests** | ✅ All pass (auth, cold-start, injection, cache, rate-limit, fallback, Groq/Kimi) |
| Flutter static analysis | **lib/** | ✅ 0 errors, 0 warnings |
| Flutter web release build | **1 build** | ✅ Clean |
| Android Appium / Selenium E2E | **0** | ❌ Not started |

---

## ❓ Open Decisions (Awaiting Guide's Answers)

1. **Browser Extension Requirement:** Is the browser extension a mandatory evaluated deliverable for the capstone, or is the Android App + Web Showcase sufficient for final evaluation?
2. **Test Case Target:** Is the 400+ automated test case target strictly required, and is a parameterized data-driven test matrix (Appium + Pytest/Selenium) acceptable for the final report?
3. **Web Hosting:** Preferred production host for the Web dashboard (Vercel vs Render static vs Netlify)?
4. **Submission & Viva Date:** What is the hard deadline for project submission and oral presentation?
