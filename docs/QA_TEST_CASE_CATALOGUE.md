# FocusEcho Production-Readiness Test Case Catalogue

## Purpose and execution rules

This catalogue defines distinct, evidence-based cases for FocusEcho's Flutter app, web experience, browser extension, and FastAPI backend. It is based on repository features and the final-year testing playbook. A case is not a pass because its test file exists or its action completed without an exception.

All cases start as **Not Run**. Record actual results, evidence, environment, and build/version after execution. A release candidate qualifies only when every in-scope, executable case passes; blocked or skipped cases do not count as passes. Do not weaken an assertion to obtain a green result.

Production scope includes safe availability checks and the explicitly authorized synthetic authentication probes below. These probes use a reserved `.invalid` address and do not use a real account. They must not create/delete users, write focus data, or access another person's records. Data mutation, load, and active vulnerability probes remain confined to local or isolated test services. Never run load or destructive/security stress tests against production.

The mobile application source is out of scope for changes. Appium cases may use a separate test harness; any case that requires a production-code test identifier or behavior change must be reported as blocked for review.

## Local test commands already defined by the repository

| Component | Local command | Scope |
| --- | --- | --- |
| Backend unit/API | `python -m pytest app/tests -q` from `backend/` | FastAPI routes, schemas, coach and rule logic; most service tests use isolated mocks. |
| Flutter unit/widget | `flutter test --no-pub` from `mobile_app/` | Existing Flutter model, view-model, route, and widget behavior. |
| Extension | `npm run test:all` from `browser_extension/` | Manifest, state machine, sync, parking lot, notifications, and replay scenarios. |

The old 14-suite Selenium catalogue was generated for the legacy static page, counted duplicate scenarios as separate coverage, and accepted action-only or `None` results as passes. Those definitions have been retired and replaced by ten explicit browser assertions. Selenium browser runs still require a working local target and compatible browser driver. Appium is not configured; local load and vulnerability runners are listed below.

## Mapping to retained tests

The cases below extend or organize existing tests; they do not replace the backend, Flutter, or extension test suites. The exact catalogue case remains **Not Run** until that journey itself has evidence.

| Catalogue cases | Existing implementation-level coverage to retain | Gap addressed by the catalogue |
| --- | --- | --- |
| `API-AUTH-001`, `API-OWNER-001`, `API-VALID-001` | `backend/app/tests/test_session_event_routes.py` | Documents end-to-end ownership and payload scenarios for isolated database verification. |
| `API-COACH-001` | `backend/app/tests/test_coach_service.py` | Connects opt-in and parked-text privacy requirements to user-visible debrief behavior. |
| `API-DELETE-001` | No existing automated deletion integration case found | Requires isolated database evidence across every owned table. |
| `UNIT-SESSION-001`, `UNIT-MIGRATION-001`, `UNIT-SYNC-001` | `mobile_app/test/session_reflection_test.dart`, `database_upgrade_test.dart`, `focus_preferences_conflict_test.dart` | Distinguishes serialization and SQL statement checks from real old-database/data-preservation checks. |
| Extension state and sync cases | `browser_extension/tests/state-machine.test.js`, `database-sync.test.js`, `replay-real-use.mjs` | Adds user-journey labels and evidence expectations to existing behavior tests. |
| `DEMO-WEB-*` browser acceptance cases | `automation/tests/test_web_acceptance.py` | Replaces duplicate/pass-on-action cases with ten explicit postcondition checks for the selected legacy static site. |
| `MOB-*`, `LOAD-*`, `SEC-*` | No complete Appium or load runner is currently configured | Defines needed cases without falsely claiming automated execution. |

The deleted Selenium filler is not counted as coverage. Backend, Flutter, and extension unit tests remain in their original directories. The `WEB-*` journeys below are the desired Flutter web end-to-end scope; the executable `DEMO-WEB-*` Selenium suite targets the selected legacy GitHub Pages app. They are intentionally listed separately because they are different deployed applications.

## Browser end-to-end cases — Selenium

Run against the local Flutter web build for functional journeys once Selenium selectors and target setup are available. The requester selected the legacy GitHub Pages URL for production smoke and synthetic auth probes; the current API production URL still needs confirmation for API checks. Use only a reserved synthetic identity for the authorized production probes and a dedicated test identity for local authenticated journeys.

| Test ID | Test case name | Preconditions and procedure | Expected result | Target | Status |
| --- | --- | --- | --- | --- | --- |
| WEB-ONB-001 | Consent is required before entering the application | Clear browser storage; open the app; attempt to navigate directly to the dashboard before accepting consent. | Consent remains the required route and the dashboard is not exposed before the choice is saved. | Local | Not Run |
| WEB-AUTH-001 | Guest access reaches the dashboard without creating an account | Complete consent; choose Continue without account; follow the router to the main shell. | Dashboard renders; no password or OTP is requested; guest mode is visible where the UI provides identity state. | Local | Not Run |
| WEB-AUTH-002 | Invalid email and password are rejected with a useful message | Open sign-in; submit malformed email, then valid-format email with incorrect password using a test identity. | Client validation prevents malformed submission; invalid credentials do not create a session and show a non-sensitive error. | Local/test auth | Not Run |
| WEB-AUTH-003 | Successful sign-in restores the user's authorized app state | Sign in using a dedicated test identity with existing synthetic data. | Auth state becomes active and the app routes to the intended post-login page without displaying another user's data. | Local/test auth | Not Run |
| WEB-SESSION-001 | A focus session requires a non-empty intention | Open session setup; submit with the intention empty; then enter an intention and start. | Empty intention is rejected; valid intention starts a timer and displays the active session state. | Local | Not Run |
| WEB-SESSION-002 | Ending a session saves its summary and optional reflection | Start a session; end it; enter rating and drift reason; repeat once while skipping reflection. | Both sessions are saved; supplied reflection persists; skipped fields remain null; each summary matches its session. | Local/test backend | Not Run |
| WEB-PARK-001 | Parking-lot entries persist and obey input limits | During an active session add, remove, refresh, and inspect entries; try 121 characters and a 21st item. | Valid entries persist; removed entries stay removed; over-limit input is rejected without altering saved items. | Local | Not Run |
| WEB-SYNC-001 | Saved site preferences are not overwritten by a session snapshot | Save a site list; start a session and remove a site from the session-only snapshot; reload preferences. | The saved list remains unchanged while the active session uses its own snapshot. | Local/test backend | Not Run |
| DEMO-PROD-001 | Selected GitHub Pages entry point serves the static FocusEcho experience | Open the selected GitHub Pages URL and inspect response, title, and app bootstrap. | HTTPS page returns successfully and renders the FocusEcho static shell without a fatal bootstrap error. | Production, read-only | Not Run |
| DEMO-PROD-AUTH-001 | An unissued one-time code cannot authenticate a synthetic identity | In a clean browser profile enter the reserved `.invalid` email and an arbitrary six-digit code. | Server-issued verification is required; no authenticated session or fabricated token is created. | Production, synthetic identity only | Not Run |
| DEMO-PROD-AUTH-002 | Guest access remains distinct from authenticated access | Start a clean browser profile; choose guest access; inspect the rendered identity and navigation state. | Guest mode is clearly identified and has no authenticated privileges or fabricated server credential. | Production, browser-local state only | Not Run |

## Selected GitHub Pages Selenium acceptance cases

These cases target the legacy static app in `web/`, which is what the requester selected as the production site. They are distinct from `WEB-*`, which describes the Flutter web app. All rows begin as **Not Run** until the Selenium suite produces evidence.

| Test ID | Test case name | Preconditions and procedure | Expected result | Target | Status |
| --- | --- | --- | --- | --- | --- |
| DEMO-WEB-SHELL-001 | Core application shell loads with dashboard navigation | Open the configured base URL and inspect title, navigation, and dashboard landmarks. | FocusEcho title, primary navigation, and dashboard are rendered. | Local legacy static app | Passed |
| DEMO-WEB-NAV-001 | Primary navigation selects the focus timer | Select Focus Timer and inspect the URL and active section. | Timer route and section become active. | Local legacy static app | Passed |
| DEMO-WEB-AUTH-001 | Guest access returns the interface to an identified guest state | Open account access, choose Guest Mode, and continue. | Guest identity and Free Tier role are displayed; the guest remains unauthenticated and has no server token. | Local legacy static app | Passed |
| DEMO-WEB-AUTH-002 | Malformed email is rejected before authenticated state is created | Submit a malformed address to the client validator and inspect error and auth state. | Validation fails and the session remains unauthenticated. | Local legacy static app | Passed |
| DEMO-WEB-AUTH-003 | A one-time code shorter than six digits is rejected | Submit a reserved synthetic address with a three-digit code. | Validation fails and no auth state is created. | Local legacy static app | Passed |
| DEMO-WEB-AUTH-004 | An unissued six-digit code cannot create an authenticated session | Submit an arbitrary six-digit code for the reserved `.invalid` address. | The unissued code is denied and no authenticated session or token is created. | Local legacy static app | Passed |
| DEMO-WEB-SESSION-001 | Timer start, pause, resume, and stop preserve valid state transitions | Enter a focus goal and trigger start, pause, resume, and stop. | State sequence is RUNNING → PAUSED → RUNNING → IDLE. | Local legacy static app | Passed |
| DEMO-WEB-PARK-001 | Parking-lot entries can be added and removed without changing existing entries | Add a unique synthetic thought, inspect it, then remove it. | New item appears once, disappears after removal, and earlier items remain intact. | Local legacy static app | Passed |
| DEMO-WEB-REFLECT-001 | Saving a reflection displays confirmation feedback | Open reflection and submit the form. | Success confirmation becomes visible. | Local legacy static app | Passed |
| DEMO-WEB-PROFILE-001 | Malformed profile email is rejected without updating the profile | Enter an invalid email in Settings and attempt to save. | Browser validation blocks submission and the profile identity stays unchanged. | Local legacy static app | Passed |

## Android end-to-end cases — Appium

Run on a named emulator/device and a debug or profile APK built with test configuration. Record model, Android version, app version, Appium/driver versions, screenshots, and relevant logcat. System permission prompts and real app-switch behavior must be tested on device; mock broadcasts alone do not prove detection.

| Test ID | Test case name | Preconditions and procedure | Expected result | Target | Status |
| --- | --- | --- | --- | --- | --- |
| MOB-ONB-001 | Fresh installation completes consent and onboarding in order | Clear app data; install APK; complete consent, permission wizard, and app selection. | Consent cannot be bypassed; onboarding reaches the dashboard after required steps. | Emulator/device | Not Run |
| MOB-PERM-001 | Denied usage access produces a clear recovery path | Deny Usage Access, return to the app, and attempt to continue. | The app explains the missing access, remains stable, and offers the route to grant it. | Emulator/device | Not Run |
| MOB-AUTH-001 | Password sign-in preserves the authenticated identity | Use a test account; sign in, close/reopen the app, then sign out. | Sign-in succeeds; the same account remains active after restart; sign-out returns to guest/auth state without exposing credentials. | Emulator/test auth | Not Run |
| MOB-SESSION-001 | Focus session starts only after a valid intention is entered | Submit setup empty, then enter an intention and start a session. | Empty input is rejected; valid input starts the timer and foreground notification. | Emulator/device | Not Run |
| MOB-SESSION-002 | Break and resume retain elapsed time and distraction count | Start session; pause with Take a Break; resume; record one distraction; force-stop and reopen. | Session recovers according to product policy; elapsed time and recorded distraction count are not reset. | Emulator/device | Not Run |
| MOB-DRIFT-001 | Repeated distraction escalation follows configured thresholds | Open a configured distracting app, return, and repeat through each escalation threshold. | Counts and intervention levels match the documented thresholds; returning to FocusEcho navigates to the active session. | Physical Android device | Not Run |
| MOB-LIFE-001 | Screen lock and app backgrounding do not silently stop tracking | Start a session; lock the screen, unlock, and background the app. | Foreground service/notification remains visible as designed, detection resumes, and no duplicate or missing session events appear. | Physical Android device | Not Run |
| MOB-SYNC-001 | Offline session data synchronizes after connectivity returns | Start and finish a session in airplane mode; restore network; inspect the test backend. | Local session remains intact and later syncs once with reflection fields and no duplicate events. | Emulator/test backend | Not Run |

## Unit and API contract cases

| Test ID | Test case name | Preconditions and procedure | Expected result | Target | Status |
| --- | --- | --- | --- | --- | --- |
| UNIT-SESSION-001 | Session reflection round-trips through local storage | Serialize and restore a session with rating, drift reason, and parked items; repeat with skipped values. | Values round-trip exactly; omitted optional values remain null. | Local | Not Run |
| UNIT-MIGRATION-001 | Existing session records survive the reflection schema upgrade | Create a database using the previous schema with existing rows; perform the production migration path; read rows and new fields. | Existing data remains unchanged; new nullable columns are available; running the upgrade twice is safely handled or explicitly prevented. | Local temporary database | Not Run |
| UNIT-SYNC-001 | Concurrent preference edits use the documented timestamp conflict rule | Compare local and remote versions with older, newer, equal, and invalid timestamps. | The documented winner is selected deterministically; session site snapshots do not mutate the saved list. | Local | Not Run |
| API-AUTH-001 | Protected session and event routes reject missing and invalid bearer tokens | Call each protected route with no token and a malformed token. | Requests are rejected with the documented authentication status and no database write occurs. | Local test backend | Not Run |
| API-OWNER-001 | A user cannot create, update, or append events to another user's session | Create synthetic users A and B; use B's token with A's session identifier for create/update/events. | Cross-user requests are rejected; A's session and event rows remain unchanged. | Local test backend/database | Not Run |
| API-VALID-001 | Event batch size and payload schema boundaries are enforced | Submit empty, malformed, maximum-valid, and one-over-limit event batches. | Valid bounded payloads are accepted; invalid payloads receive client errors and create no partial rows. | Local test backend | Not Run |
| API-COACH-001 | Coach opt-in and reflection privacy are enforced server-side | With opt-in disabled, request a debrief; then enable it and include reflection plus parked entries. | Disabled state makes no LLM call; enabled request receives aggregate counts/tags, never parked-item text. | Local mocked backend | Not Run |
| API-DELETE-001 | Account data deletion removes all owned application records | Against disposable test data, request deletion and query all owned app/coach tables. | Owned rows are removed; unrelated user rows remain; repeat request behavior is documented. | Isolated test database only | Not Run |

## Load smoke cases — local in-process mock only

The runner uses FastAPI TestClient with mocked persistence. It validates endpoint behavior, concurrency handling, retry behavior, and reports latency; it does **not** exercise Supabase, deployed infrastructure, or production capacity. Local P95 budgets are 1,000 ms for ordinary requests and 2,000 ms for a 500-event batch. These are smoke budgets, not production SLAs.

| Test ID | Test case name | Workload | Pass criteria | Target | Status |
| --- | --- | --- | --- | --- | --- |
| LOAD-HEALTH-001 | Health endpoint baseline concurrency | 100 requests, concurrency 10 | Zero errors; P95 ≤ 1,000 ms | Local mocked backend | Passed |
| LOAD-HEALTH-002 | Health endpoint burst concurrency | 150 requests, concurrency 30 | Zero errors; P95 ≤ 1,000 ms | Local mocked backend | Passed |
| LOAD-SESSION-001 | Concurrent session creation | 50 requests, concurrency 10 | All creates accepted; zero errors; P95 ≤ 1,000 ms | Local mocked backend | Passed |
| LOAD-SESSION-002 | Concurrent session reflection updates | 50 requests, concurrency 10 | All updates accepted; zero errors; P95 ≤ 1,000 ms | Local mocked backend | Passed |
| LOAD-EVENT-001 | Concurrent event batch ingestion | 50 batches of 20, concurrency 10 | All batches accepted; zero errors; P95 ≤ 1,000 ms | Local mocked backend | Passed |
| LOAD-EVENT-002 | Maximum-size 500-event batch | 10 requests, concurrency 5 | All batches accepted; zero errors; P95 ≤ 2,000 ms | Local mocked backend | Passed |
| LOAD-RETRY-001 | Health request retry resilience | 30 requests, concurrency 10, up to 2 attempts | Requests succeed; zero terminal errors; P95 ≤ 1,000 ms | Local mocked backend | Passed |
| LOAD-PERF-001 | Sustained health endpoint workload | 250 requests, concurrency 25 | Zero errors; P95 ≤ 1,000 ms | Local mocked backend | Passed |

## Security checks — local only

These probes use TestClient and mock-owned rows where applicable. They do not replace a penetration test, production scanning, or database-backed authorization verification. The source scanner reports file paths only.

| Test ID | Test case name | Procedure | Expected result | Target | Status |
| --- | --- | --- | --- | --- | --- |
| VULN-AUTH-001 | Missing bearer token is rejected | POST to a protected session route without Authorization. | HTTP 401/403; no write. | Local API | Passed |
| VULN-AUTH-002 | Malformed bearer token is rejected | Submit an invalid JWT-shaped token. | HTTP 401/403, no trace disclosure. | Local API | Passed |
| VULN-AUTH-003 | Unsigned JWT is rejected | Submit an `alg=none` token. | HTTP 401/403. | Local API | Passed |
| VULN-IDOR-001 | Cross-user session update is denied | User B attempts to update user A's session. | HTTP 403; foreign row unchanged. | Local API with mock row | Passed |
| VULN-IDOR-002 | Cross-user event batch is denied | User B appends events to user A's session. | HTTP 403; no event write. | Local API with mock row | Passed |
| VULN-LIMIT-001 | Oversized event batch is rejected | Submit 501 events. | HTTP 422 before DB processing. | Local API | Passed |
| VULN-INJECT-001 | SQL-like session path is safely handled | Submit an injection-shaped session identifier. | Client error; no SQL syntax trace. | Local API | Passed |
| VULN-VALID-001 | Out-of-range focus rating is rejected | Submit focus_rating 99. | HTTP 422. | Local API | Passed |
| VULN-VALID-002 | Unsupported drift reason is rejected | Submit an unknown drift_reason. | HTTP 422. | Local API | Passed |
| VULN-SECRETS-001 | Repository scan finds no private-key PEM block | Scan tracked and unignored working files; report paths only. | No complete private-key block found. | Local source tree | Passed |

## Qualification and evidence

For each executed case, record actual output, status, environment, timestamp, app/build commit, and a screenshot/log/request ID where appropriate. For a case that cannot run because a URL, test identity, emulator, or isolated database is unavailable, use **Blocked** and explain the missing prerequisite. A blocked case is not a pass.

## Execution evidence and blockers

Local executable suites were run on 2026-11-05. Results below distinguish automated local checks from device, deployment, and real-infrastructure checks. A local pass does not imply a production pass.

| Suite | Result | Evidence and scope |
| --- | --- | --- |
| Backend API/unit | 85 passed, 0 failed | `python -m pytest app/tests -q` from `backend/`; 2 deprecation warnings. |
| Flutter unit/widget | 91 passed, 0 failed | `flutter test --no-pub`; no physical device or Flutter web browser E2E was exercised. |
| Browser extension | 227 established checks plus the standalone parking-lot check passed | `npm run test:all`; state machine 177, DB sync 36, desktop notifications 4, replay scenarios 9, manifest integrity check 1, parking-lot popup check 1; the redundant 67-check extended-coverage suite was removed. |
| Selenium legacy web acceptance | 10 passed, 0 failed, 0 skipped | Edge headless against local `http://127.0.0.1:8081/`; all ten `DEMO-WEB-*` cases passed. This targets the legacy static app, not Flutter web. |
| QA catalogue controls | 14 passed, 0 failed | `python -m pytest automation/test_quality_controls.py -q`; includes runner/case integrity, load/security helper, and CI-gate parser checks. |
| Local load smoke | 8 passed, 0 failed | `python automation/load/runner.py`; TestClient with mocked persistence. P95 measurements are diagnostic local smoke evidence, not production capacity evidence. |
| Local vulnerability checks | 10 passed, 0 failed | `python automation/vulnerability/runner.py`; TestClient/mock probes and local source scan. Not an external penetration test. |
| **Automated total** | **446 passed, 0 failed** | Counts the extension parking-lot check separately: 85 + 91 + 228 + 10 + 14 + 8 + 10. |

The earlier 402 total used a stale Flutter count of 47. The checked-in Flutter suite currently reports 91 cases, so the accurate aggregate is 446. Counts combine unit cases, browser cases, and runner controls; they are not 446 independent production end-to-end journeys.

CI also creates `Test Results/Excel/Full_Test_Suite_Report.xlsx`, with one row per named check and a suite summary sheet. The Selenium-specific workbook remains available separately. Both are included in the `focusecho-test-results` Actions artifact.

### Not executed / blocked

| Scope | Status | Reason |
| --- | --- | --- |
| Android Appium/device cases (8) | Blocked | No configured Appium server/device run or captured device evidence. |
| Flutter web E2E cases (8) | Not run | Selenium suite targets legacy `web/`; no browser run against a built Flutter web app. |
| Supabase deletion cascade integration | Not run | Requires disposable test project and database-row verification. |
| Production web/API smoke | Not run | Local runs only; no production probe was made during this execution. |
| Real-backend load and external vulnerability assessment | Not run | Current runners mock persistence and use in-process TestClient; they do not establish deployed-service capacity or penetration-test coverage. |

Do not describe the app as fully production-qualified while these items remain unexecuted. The 402 count is the number of locally executed automated checks from the suites listed above; blocked and not-run checks are excluded.

