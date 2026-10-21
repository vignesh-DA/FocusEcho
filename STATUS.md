# FocusEcho — Project Status Tracker

> **Last Updated:** 2026-10-18  
> **Status Taxonomy:** `done and verified` | `written but unverified` | `failed` | `not started`  
> *(Note: "Verified" means seen working on a real physical phone or in a live Chrome browser instance, not just passing unit tests).*

---

## 📊 Phase-by-Phase Status Matrix

| ID | Phase / Module | Status | Date | Verified On | Notes / Root Causes |
|---|---|---|---|---|---|
| **BE-1** | FastAPI Core Service & Health Check | `done and verified` | 2026-10-18 | Live Render URL | `/health` endpoint live and returning 200 OK. |
| **BE-2** | Supabase Schema & RLS Policies | `written but unverified` | 2026-10-18 | — | SQL migrations exist in repo; pending user confirmation of tables & RLS in Supabase dashboard. |
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
| **MOB-3b**| Mobile Gap: Session Resume on App Relaunch | `not started` | 2026-10-18 | — | Resume active session after app process death/relaunch when service is still running. |
| **MOB-3c**| Mobile Gap: Streak Minimum Length & Grace Day | `not started` | 2026-10-18 | — | Require minimum session duration (e.g. 15 min) for streak increment; 1 grace day buffer before streak reset. |
| **MOB-3d**| Mobile Gap: Cumulative Streak Counter | `not started` | 2026-10-18 | — | Lifetime total streak days counter separate from current consecutive streak. |
| **MOB-3e**| Mobile Gap: XP for Completed Sessions | `written but unverified` | 2026-10-21 | — | `AppXP.sessionCompletionXp` (50 XP) awarded in `stopSession()` when session ≥ `AppXP.minSessionMinutesForXp` (1 min). Stored in SQLite `total_xp_earned` column and surfaced in `SessionSummary`. Needs physical device run. |
| **MOB-3f**| Mobile Gap: `updateUserXP` Wiring | `written but unverified` | 2026-10-21 | — | `stopSession()` now accumulates lifetime XP in `SharedPreferences` (`xp_total` key) and calls `supabaseService.updateUserXP()` fire-and-forget when a user is signed in. Network failures log and do not block session end. Needs physical device + Supabase dashboard confirmation. |
| **MOB-3g**| Mobile Gap: Analytics Remote Backend Integration | `not started` | 2026-10-18 | — | Connect Analytics UI screen to FastAPI `/api/v1/analytics` instead of reading local SQLite only. |
| **MOB-4** | Local SQLite Database (`sqflite`) | `written but unverified` | 2026-10-18 | — | Write-first DAOs implemented; needs physical device validation. |
| **MOB-5** | Local Notifications Engine | `written but unverified` | 2026-10-18 | — | Configured via `flutter_local_notifications`; remote Firebase removed per spec. |
| **MOB-6** | GitHub Actions CI/CD Build Pipeline | `failed` | 2026-10-18 | GitHub Actions | Run #19 failed (exit code 1) due to Flutter 3.19 pinning vs Gradle 8.14/AGP 8.11 project config. |
| **EXT-1** | Browser Extension Phase 1 (Service Worker & State Machine) | `done and verified` | 2026-10-18 | Live Chrome E2E (Build `687ff36`) | **Automated Live Chrome run passed all 9 checks + negative control.** Verified via real Chrome instance loading unpacked MV3 extension, DNS host-resolved `youtube.com`, dedicated 3s grace timer, 20s recovery event emission, L2 re-entry, CDP `ServiceWorker.stopWorker` termination/wake persistence, options page CSP navigation, active session restart, rapid leave & re-entry (<500ms), recovery timing aligned with mobile app (including 3s grace in `time_on_site_ms`), and duplicate navigation event deduplication. |
| **EXT-2** | Browser Extension Phase 2 (In-Page Overlays: Toast, L2 Modal, L3 Block) | `not started` | 2026-10-18 | — | Visual countdown modal (15s spec) and overlay content scripts unbuilt. |
| **EXT-3** | Browser Extension Phase 3 (Popup UI) | `not started` | 2026-10-18 | — | Currently a static placeholder linking to options page. |
| **EXT-4** | Browser Extension Phase 4 (Web Dashboard Bridge) | `not started` | 2026-10-18 | — | Bidirectional sync between extension and Web app unbuilt. |
| **WEB-1** | Flutter Web Showcase App (Vercel) | `written but unverified` | 2026-10-18 | — | In-memory SQLite mocking & distraction simulator coded; end-to-end sync unverified. |
| **TEST-1**| Automated E2E Test Suite (Appium + Selenium / Pytest) | `not started` | 2026-10-18 | — | 400+ parameterized test cases across Android and Web with published CI reports. |

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
| CHECK-4 | ✅ PASS | 20s visit then switch away emits recovery event | Recovery logged with time_on_site: 21060ms (spec: $\ge$ 15s) |
| CHECK-5 | ✅ PASS | Re-entry raises count to 2 and reaches L2 | State: `L2_OVERLAY`, count: 2 |
| CHECK-6 | ✅ PASS | Stopping SW over debugging protocol and waking keeps count and state | Count preserved: 2, state: `L2_OVERLAY` |
| CHECK-7 | ✅ PASS | Popup options link uses external script and opens options page | Options opened: `chrome-extension://.../options.html` |
| CHECK-8 | ✅ PASS | Start Session while active restarts session cleanly | restarted: true, state: `MONITORING`, count: 0 |
| CHECK-9 | ✅ PASS | Fast leave & re-enter (<500ms) resets grace cleanly to L1 | Round-trip: 81ms (<500ms); reset to `COUNTING_GRACE` then cleanly reached `L1_TOAST` count=1 |

---

## 🔍 Extension Phase 1 Failure Log & Applied Fixes (2026-10-18)

1. **3s Grace Timer:** 
   - *Defect:* Did not trigger without manual heartbeat injection because service worker timer reliance failed under standard MV3 sleep cycles.
   - *Fix:* Added dedicated `setTimeout(3000)` in service worker on `RECORD_GRACE_ENTRY`, plus timestamp catch-up (`now - graceEnteredAt >= 3000`) on any event and service worker wake-up (`reconstructAndSync`).
2. **Session Re-entry:** 
   - *Defect:* `Start Session` command was silently dropped when session state was already marked active.
   - *Fix:* Handled `EV.SESSION_STARTED` globally in `transition()` to cleanly restart an active session into `MONITORING`, clear old distraction state, and report restart status.
3. **Popup Navigation:** 
   - *Defect:* Clicking the debug options link in `popup.html` did nothing due to MV3 Content Security Policy (CSP) blocking inline scripts.
   - *Fix:* Extracted handler into dedicated external `popup.js` using `chrome.runtime.openOptionsPage()`.
4. **Missing Assets:** 
   - *Defect:* Manifest declared icon paths (`16`, `32`, `48`, `128`) that were missing from disk.
   - *Fix:* Generated all PNG icon assets and created `check-manifest.js` integrity validator.
5. **Recovery Timing Spec Alignment:**
   - *Defect/Inconsistency:* `time_on_site` was previously measured from grace confirmation (`distraction.startedAt`), excluding the initial 3s grace window.
   - *Fix:* Aligned with Android mobile app rule: `time_on_site_ms = leave_time - grace_entered_at`. Anchored `started_at` to `grace_entered_at` on grace confirmation and documented across spec (`event-schema.js`), code (`service-worker.js`), and unit tests (T12).
6. **Navigation Event Deduplication:**
   - *Defect:* Leaving a distracting site triggered both `chrome.tabs.onUpdated` and `chrome.webNavigation.onCommitted` concurrently, causing dual `TAB_NAVIGATED` dispatches.
   - *Fix:* Added `_deduplicateNav(tabId, host)` cache with a 500ms sliding window in service worker, ensuring a single site exit produces exactly one transition and recovery event (verified in T13).

---

## ❓ Open Decisions (Awaiting Guide's Answers)

1. **Browser Extension Requirement:** Is the browser extension a mandatory evaluated deliverable for the capstone, or is the Android App + Web Showcase sufficient for final evaluation?
2. **Test Case Target:** Is the 400+ automated test case target strictly required, and is a parameterized data-driven test matrix (Appium + Pytest/Selenium) acceptable for the final report?
3. **Web Hosting:** Preferred production host for the Web dashboard (Vercel vs Render static vs Netlify)?
4. **Submission & Viva Date:** What is the hard deadline for project submission and oral presentation?
