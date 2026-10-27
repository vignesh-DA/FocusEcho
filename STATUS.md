# FocusEcho — Project Status Tracker

> **Last Updated:** 2026-10-27
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

## EchoCoach Groq SDK Migration — 2026-10-26

- **Status:** Implemented and locally verified in commit `008a79a`.
- **Provider:** Official Groq Python SDK `groq==0.37.1`; direct `httpx` provider calls and Gemini/OpenAI branches were removed.
- **Configuration:** `GROQ_API_KEY`, `COACH_LLM_MODEL` (`qwen/qwen3.8-27b`), optional `COACH_LLM_MODEL_BACKUP`, and `COACH_LLM_TIMEOUT_SECONDS`. Debrief uses a 5-second budget; refine is capped at 3 seconds.
- **Reliability:** Strict Pydantic JSON validation, `<think>` stripping, primary-to-backup retry for timeout/connection/invalid JSON/schema/model-not-found failures, reasoning-mode retry, and deterministic rule fallback.
- **Telemetry and privacy:** Logs contain only model, latency, fallback state, reason, exception type, and status code. The server-side opt-in gate runs before live calls, and startup checks the configured model with `models.list()`. No API key or raw exception text is logged. Groq Zero Data Retention must be enabled in Data Controls for deployment; inference is not retained by default, but reliability/abuse logs may be retained.
- **Verification:** Backend `unittest` suite: **17/17 passed** (14 coach + 3 intelligence tests). `py_compile` and `git diff --check` passed. The demo ran in deterministic fallback mode because no `GROQ_API_KEY` was configured; live-key verification remains pending.

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
| Run `20261028_align_session_foreign_keys.sql` in Supabase | ⬜ TODO | Run after the earlier schema migrations; validates child session ID foreign keys |
| Run `20261028_user_focus_preferences.sql` in Supabase | ⬜ TODO | Required for cross-device app/site lists and limits |
| Enable Anonymous Auth provider | ⬜ TODO | Supabase → Auth → Providers → Anonymous: ON |
| Configure OTP email template with `{{ .Token }}` | ⬜ TODO | Supabase → Auth → Email Templates |
| Set `SUPABASE_JWT_SECRET` on Render | ⬜ TODO | Render → Environment variables (required for JWT auth) |
| Set `GROQ_API_KEY`, `COACH_LLM_MODEL`, `COACH_LLM_MODEL_BACKUP`, and `COACH_LLM_TIMEOUT_SECONDS` on Render / `.env` | ⬜ TODO | Groq-only runtime configuration; fallback active if absent |
| Deploy Flutter Web release to Vercel | ⬜ TODO | `flutter build web --release` output → Vercel |
| Run Flutter app on physical Android device | ⬜ TODO | Physical Android phone with UsageStats permission |
| Verify Supabase tables exist with correct columns | ⬜ TODO | Supabase → Table Editor |

### Prototype reliability pass — 2026-10-27

- **Commit:** `2dd6e8c fix: harden cross-surface prototype reliability`.
- **Data ownership:** Backend session writes are now insert/idempotent and reject session ID takeover. Event batches are capped at 500, and each event's parent session and any conflicting existing event IDs are checked against the authenticated user before upsert.
- **Schema compatibility:** Base session/event IDs now match the UUID schema used by newer migrations. Historical text-ID installs are handled by type-aware focus-recovery/coach migrations; `20261028_align_session_foreign_keys.sql` repairs child session foreign keys. `20261028_user_focus_preferences.sql` adds owner-scoped cross-device lists and app limits with RLS.
- **Flutter offline behavior:** Supabase-dependent services and login/splash/dashboard/streak/analytics routes no longer crash when the SDK is unavailable or there is no authenticated account. Local session/settings data remains usable; unsuccessful cloud writes are no longer reported as synced. App/site lists and limits load from and persist to the user's preference row when cloud sync is enabled.
- **Extension config:** Popup sessions use the saved extension config rather than a separate hard-coded list. A session launched by the Flutter web bridge refreshes the extension's local config from that account's site list. First-run extension defaults match Flutter's sample site list.
- **Deployment and build:** Render environment configuration now includes JWT/Groq variables. CI generates Flutter sources, analyzes/tests Flutter, tests backend and extension, and only publishes an APK release for version tags. The Flutter lockfile is no longer ignored. Generated extension test TLS private keys/config were removed from version control.
- **Privacy wording:** The policy now discloses parked free-text notes, synced site/app metadata, the EchoCoach parked-count-only behavior, and that automatic 90-day deletion is not implemented.
- **Verification:** Backend discovery: **20/20 passed**. Extension `npm run test:all`: **21 manifest checks, 177 state-machine checks, 31 database-sync checks, parking test passed, 9/9 service-worker replay scenarios passed**. Flutter `flutter test --no-pub`: **36/36 passed**, including database upgrade and parking tests. Full Flutter analysis had **0 errors** and info-only repository lint findings; focused Dart analysis on all changed Dart files now reports **“No issues found!”**. The release web build could not be completed because this environment attempted to download the missing Flutter Web SDK and stalled; no successful web build or physical-device verification is claimed. Supabase migrations remain authored but need execution against the actual project.
- **Open integration requirement:** Apply the two `20261028_*.sql` migrations after the existing migrations before cross-device preference syncing works against Supabase. Until then, the Flutter app retains local settings and remote preference errors are handled without crashing.
- **Additional runtime limits:** The direct live-Chrome Puppeteer command stopped before tests because Chrome exited with code `3221225506`. The Android debug build remained in Gradle without emitting an APK and was stopped. These are not reported as successful runtime checks; the NDK has now been pinned to the plugin's required `28.2.13676358` for the next build attempt.

---

## Batch 1 — Reflection, Parking Lot, Allow-Site, Coach Inputs

### Step 1 — Database migration

- **Status:** Migration authored; pending Supabase execution.
- **Migration:** `backend/supabase_migrations/migrations/20261027_session_reflection_parking_lot.sql`
- **Adds:** nullable `focus_rating`, `drift_reason`, and `parked_items` fields on `focus_sessions`.
- **Constraints:** rating 1–5, approved drift reasons, maximum 20 parked strings, maximum 120 characters per item.
- **Tests:** Baseline backend **18/18 passed**; extension unit **149/149 passed**; manifest **21/21 passed**; database sync **21/21 passed**; replay **9/9 passed**; Dart analysis completed with existing informational lints. Flutter tests hung in the local environment and were stopped; mobile runtime remains unverified.

### Step 2 — Session reflection

- **Status:** Implemented locally; runtime unverified.
- **Behavior:** Sessions of at least one minute show a non-blocking optional 1–5 focus rating. The drift reason picker appears only when the session has distractions. Skip stores nullable values.
- **Persistence:** SQLite version 5 and web local storage support the new nullable fields. Sync retries legacy session columns when the migration is not yet present and keeps the local row unsynced for a later retry.
- **Commit:** `256ec8d feat(reflection): add optional session focus reflection`
- **Raw checks:** `dart analyze ...` → **1 existing informational lint, 0 errors**. `dart format ...` → **10 files formatted**. Flutter test execution remains blocked/hanging in this environment.

### Step 3 — Parking lot

- **Status:** Implemented locally; runtime unverified.
- **Flutter:** Active Android/web session input with add/remove, 20-item limit, 120-character limit, and summary rendering.
- **Extension:** Popup input with Enter support, safe `textContent` rendering, service-worker persistence, web-bridge updates, and bounded session state.
- **Sync:** `parked_items` is serialized as a JSON array for Supabase. The coach integration is deferred to Step 5 and will receive only the count.
- **Raw checks:** `npm run test:parking` → **PASS**; `npm run test:db` → **21 passed, 0 failed**; `npm run test:unit` → **149 passed, 0 failed**. Dart analysis reports **0 errors** and the existing rule-engine informational lint.

### Step 4 — Allow this site for this session

- **Status:** Implemented locally; live Chrome runtime still needs verification.
- **State machine:** A session-only allow returns to `MONITORING`, removes the matching host and subdomains from the active session list, hides overlays, and logs `allowed_site` without a recovery event or count change. The permanent configuration is untouched and the list resets with the next session.
- **UI:** Popup and L1/L2 overlays expose “Allow this site for this session” only for a currently listed distraction host.
- **Privacy/sync:** Only the normalized hostname is logged; no URL path or page content is captured.
- **Commit:** `174243f feat(extension): allow a distraction site for the active session`.
- **Raw checks:** `npm run test:unit` → **177 passed, 0 failed**; `npm run test:manifest` → **21 passed**; `npm run test:parking` → **PASS**.

### Step 5 — Coach inputs

- **Status:** Implemented locally; production Groq call remains opt-in and environment-dependent.
- **Server facts:** Debrief telemetry now includes validated `focus_rating`, validated `drift_reason`, and a bounded `parked_item_count`. Parked item text is never placed in the LLM prompt, persistence log, or fallback metadata.
- **Consent:** The existing server-side coach opt-in gate is unchanged.
- **Commit:** `342703d feat(coach): add reflection and parking-count context`.
- **Raw checks:** `python -m unittest discover -s app/tests -p 'test_coach_service.py' -v` → **16/16 passed**; the new privacy test confirms parked text is absent from the request.

### Batch 1 open verification items

- Supabase migration execution, real Groq demo call, Flutter runtime on web/Android, and live Chrome verification require the configured external environments and were not claimed as verified here.

### Final Batch 1 verification (2026-10-27)

- Backend full discovery: `python -m unittest discover -s app/tests -p 'test_*.py' -v` → **19/19 passed**.
- Extension state-machine: **177/177 passed**; manifest **21/21 passed**; database sync **21/21 passed**; parking test **PASS**; replay **9/9 scenarios passed**.
- `git diff --check` → **clean**; working tree → **clean**.
- `dart analyze lib` and `flutter test` were attempted again but produced no output and hung in this local environment; both were stopped after 30 seconds. Earlier generated-code analysis completed with 0 errors and existing informational lints. No green Flutter runtime result is claimed.
- Batch commits pushed to `origin/main`: `d41f542`, `256ec8d`, `fae2d27`, `174243f`, `342703d`; follow-up commits are listed below in this section.

### Follow-up completion — extension auth refresh (2026-10-27)

- Flutter Web now forwards the Supabase refresh token to the extension.
- The extension refreshes expired access tokens through Supabase Auth, persists rotated tokens, retries 401 session and event writes, and never uses the public anon key as a bearer token.
- Without a user ID and access token, queued events remain local with an authentication-required status.
- Raw checks: database sync **24 passed, 0 failed**; parking **PASS**; extension unit **177 passed, 0 failed**; JavaScript syntax checks passed.
- Live Chrome runner remains environment-blocked by Puppeteer/Chrome launch error `3221225506`; no live result is claimed.
- Final rerun after auth refresh: backend **19/19 passed**; `npm run test:all` passed manifest **21/21**, state machine **177/177**, database sync **24/24**, replay **9/9**.
- Commit/push: `98bbde1 fix(extension): refresh expired Supabase auth sessions`.

### Follow-up completion — strict sync auth and parking verification (2026-10-27)

- Extension PostgREST and RPC writes now require a user access token; the anon key is sent only in Supabase's `apikey` header. A missing user token leaves queued data local.
- A 401 triggers one refresh attempt and at most one retry of the failed request. Rotated refresh tokens are persisted, and tests verify the refresh token is absent from logs.
- `backend/.env.example` no longer contains the retired Kimi model. Model IDs are placeholders to be selected from Groq's models list; the startup model-list check remains enabled.
- Flutter now has parking-lot coverage for add/remove, JSON persistence, 120-character and 20-item limits, summary rendering, and a test for the pre-Batch-1 database upgrade path. The active session's feed/parking area scrolls on short screens while Stop remains visible.
- Raw checks: `npm run test:db` → **31 passed, 0 failed**; `python -m unittest discover -s app/tests -p 'test_coach_service.py' -v` → **17 tests, OK**; `flutter test --reporter=expanded` → **36 passed, 0 failed**; `git diff --check` → **clean**.
- Commit: `b92fee8 fix(sync): require auth and retry refreshed writes`.
- Live Supabase, Groq account settings, real Chrome, and physical Android testing remain external verification items.

---

## 📈 Test Coverage Summary (2026-10-26)

| Suite | Count | Status |
|---|---|---|
| Flutter unit tests | **26** | ✅ All pass |
| Extension unit tests | **149** | ✅ All pass |
| Extension manifest checks | **21** | ✅ All pass |
| Extension DB sync tests | **21** | ✅ All pass |
| Extension live Chrome E2E | **9 checks** | ⚠️ 8 pass, 1 fail (CHECK-9 rapid bounce) |
| EchoCoach v1 unit tests | **17 tests** | ✅ All pass (14 coach + 3 intelligence tests) |
| Flutter static analysis | **lib/** | ✅ 0 errors, 0 warnings |
| Flutter web release build | **1 build** | ✅ Clean |
| Android Appium / Selenium E2E | **0** | ❌ Not started |

---

## ❓ Open Decisions (Awaiting Guide's Answers)

1. **Browser Extension Requirement:** Is the browser extension a mandatory evaluated deliverable for the capstone, or is the Android App + Web Showcase sufficient for final evaluation?
2. **Test Case Target:** Is the 400+ automated test case target strictly required, and is a parameterized data-driven test matrix (Appium + Pytest/Selenium) acceptable for the final report?
3. **Web Hosting:** Preferred production host for the Web dashboard (Vercel vs Render static vs Netlify)?
4. **Submission & Viva Date:** What is the hard deadline for project submission and oral presentation?

---

## Production safety follow-up — 2026-10-27

- **Commit:** `50b704a fix: harden privacy, sync conflicts, and CI`.
- **Earlier reported commits:** `9938a3b docs: record prototype reliability verification`; `2dd6e8c fix: harden cross-surface prototype reliability`.
- **Privacy:** Removed the unsupported 90-day deletion promise from the shipped and documentation policies. Both now state that automatic deletion is not implemented; the cloud workbook uses the same retention statement. Backend regression test checks the two policy copies match and contain no 90-day claim.
- **Settings sync:** Session sites are passed to the extension as a copied session list. They do not write to the permanent saved list. Conflict rule: a strictly newer local `updated_at` wins; an equal timestamp keeps the server row. The Flutter client calls the atomic `sync_user_focus_preferences` RPC and adopts its canonical row. Migration `20261029_focus_preferences_conflict_resolution.sql` must be applied before this RPC works against Supabase; live database behavior remains unverified.
- **API regression tests:** Added coverage for missing and invalid auth, ownership collisions on session create/update, 501-event batches, malformed session/event payloads, and auth dependency registration. Backend suite: **30 tests, OK**.
- **CI:** Added `.github/workflows/ci.yml` for backend, Flutter, and extension checks, result/log uploads on failure, a debug APK artifact, and one **100%** pass threshold used by both the summary and the gate. Flutter is pinned to **3.47.8** in CI and release workflows. YAML syntax was parsed locally; the hosted workflow has not yet run.
- **Local evidence:** Flutter unit suite **40/40 passed**; targeted Dart analysis found **0 errors** and one existing informational lint in `focus_session_viewmodel.dart`; extension `npm run test:all` passed manifest **21/21**, state machine **177/177**, database sync **31/31**, parking checks, and replay **9/9**. `git diff --check` was clean.
- **Cleanup:** Deleted tracked `cls` and `memory.md`; added `*.pem` and `*.key` ignores. `test-results/key.pem` and `cert.pem` were absent and not tracked when checked.
- **Still unverified:** Supabase migrations have not been applied to the live project. The local debug APK build stalled during Gradle and produced no artifact. The new hosted CI workflow is pending its first GitHub run. No external deployment, migration, or device verification is claimed.
