# FocusEcho — Changelog

> All notable changes to FocusEcho, organised by surface area.
> Format inspired by [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased] — 2026-10-25

---

### 🌐 Web App (Flutter Web)

#### 🔐 Auth

- **Fixed OTP code length** — Login screen previously enforced a 6-digit OTP input (`maxLength: 6`). Supabase email auth sends **8-digit** codes. Updated `maxLength`, hint text, and prompt label in `login_screen.dart` to accept 8-digit codes correctly.

---

#### 🏠 Home Dashboard

- **Fixed stale userId on dashboard load** — `DashboardViewModel` was initialised at app startup with `prefs.getString(AppKeys.userId)`, which could be `'local-user'` or empty before OTP login completed. Provider now uses `Supabase.instance.client.auth.currentUser?.id` as the **live** auth id at both construction time and inside `loadDashboard()`, ensuring queries always run as the correct authenticated user.

- **Fixed XP showing 0 on Home while Streaks showed 225** — Root cause: Dashboard read `totalXp` from the `users` table via `getUserProfile()`, but XP is actually stored in the separate `user_xp` table. Dashboard now also queries `user_xp` directly (identical to the Streaks viewmodel), then merges the result onto the profile via `copyWith`. If no `users` row exists yet (new account), a synthetic `UserProfile` is constructed from the `user_xp` row so XP and streak still display.

- **Fixed 0 sessions displayed on Home** — Session queries now run as the authenticated user (via live auth id), so Supabase RLS correctly returns the user's own `focus_sessions` rows. Previously the stale `'local-user'` id meant RLS filtered everything out.

- **Expanded dashboard session query window** — Widened from today-only to a rolling 7-day window, then filtered to local-calendar today for stats display. Matches the Analytics viewmodel logic and prevents UTC-offset sessions from being missed.

---

#### 📊 Analytics Charts

- **Weekly Focus Time bar chart** — Added `Mon Tue Wed Thu Fri Sat Sun` day labels on the X-axis via `AxisTitles` / `SideTitles`. Y-axis now shows `Xm` (minute) formatted labels. Bars have a blue gradient with rounded top corners. Right and top axes hidden.

- **Daily Distractions line chart** — X-axis previously rendered as raw floats (`0, 0.2, 0.4…`) because fl_chart auto-scaled the axis. Fixed by setting `minX: 0`, `maxX: 6`, `interval: 1` and a `getTitlesWidget` that maps index → day abbreviation. Added:
  - Translucent red area fill under the line
  - Dot markers at each data point (white-stroked circle)
  - Integer-only Y-axis labels

- **Most Distracting Apps — donut redesign** — Replaced the old solid pie chart (ugly white numbers crammed into slices) with a **premium donut** layout:
  - No text inside slices — clean pure colour segments
  - `startDegreeOffset: -90` so the first slice starts at 12 o'clock
  - **Centre hole overlay** showing total distraction count + `"total"` label in white
  - Glassmorphism card wrapper (subtle border + frosted background)
  - Legend redesigned: coloured circle · site name · `%` in matching colour · 3 px mini progress bar per row
  - Apps sorted descending by count before rendering

- **Focus Score History line chart** — Added proper `minY: 0 / maxY: 100` bounds, `#1 #2…` session labels on X-axis, area fill, dot markers, and hidden right/top axes.

- **All charts** — Suppressed right and top axis titles globally (were showing raw scale numbers by default in fl_chart).

---

#### 🪵 Structured Runtime Logging (Python-style Tracing)

- **`fe_logger.dart`** (`lib/core/utils/fe_logger.dart`) — Created a lightweight Python-style structured logger with severity levels (`DEBUG`, `INFO`, `WARN`, `ERROR`), microsecond timestamps, ANSI terminal colours, and configurable minimum level:
  - Format: `[FE <LEVEL>] [<TAG>] HH:mm:ss.ms → <MESSAGE>`
  - Tagged viewmodels: `Dashboard`, `Analytics`, `Auth`, `FocusSession`
  - Integrated into:
    - **DashboardViewModel** — traces live auth check, user profile fetch, `user_xp` queries, 7-day cloud sessions count, recovery calculation, and granular warnings/errors.
    - **AnalyticsViewModel** — logs local session/event counts, distribution grouping, and remote FastAPI backend enrichment requests.
    - **FocusSessionViewModel** — records session start, elapsed timer, extension IPC handshakes, distraction detection ladders, recovery events, and session stop XP grants.
    - **LoginViewModel** — full tracing of OTP dispatch, token length verification, anonymous account link upgrades, and Supabase auth errors.

---

#### 🎯 Focus Session Setup Redesign & Expanded Tools Library

- **Expanded default productive tools (5 → 32+ apps & sites)**:
  - Previously only had 5 hardcoded items (`Figma, VS Code, GitHub, Google Docs, Notion`).
  - Added comprehensive library: `VS Code`, `GitHub`, `GitLab`, `Cursor`, `IntelliJ IDEA`, `Terminal / CLI`, `Stack Overflow`, `Postman`, `Docker`, `Linear`, `Jira`, `Figma`, `Canva`, `Adobe Photoshop`, `Blender`, `Notion`, `Google Docs`, `Google Sheets`, `Obsidian`, `Overleaf (LaTeX)`, `Microsoft Word / Excel / Teams`, `Slack`, `ChatGPT / Claude`, `Perplexity`, `ArXiv`, `Zoom`, `Google Meet`, `Coursera`, `Khan Academy`, `Duolingo`.
  - Added auto-migration in `FocusSessionViewModel` to automatically upgrade legacy 5-item lists without wiping user preferences.
- **"+ Add Custom App" Dialog**: Users can now add any custom tool, website, or enterprise portal name on the fly, which gets persisted to local storage and selected immediately.
- **Top Productive Tools Quick-Select Chips**: Instant one-tap selection with matching icons (`💻 VS Code`, `🎨 Figma`, `🐙 GitHub`, `📓 Notion`, `📄 Google Docs`, `🤖 AI`, `💬 Slack`, `⚡ Cursor`).
- **Quick Intent Suggestions**: Interactive pill buttons (`"Deep coding session"`, `"Feature implementation"`, `"Bug fixes & tests"`, `"UI & design review"`, `"Documentation & writing"`, `"Research & study"`) to instantly pre-fill intent.
- **Responsive Layout & Dropdown Fix**: Constrained max-width to 620px to prevent stretched web layouts, fixed menu overflow height (`menuMaxHeight: 320`), and replaced the rigid circular button with a responsive, glowing gradient action button.

---

### 🧩 Browser Extension

#### 🔁 Return to Productive Tab (`NAVIGATE_BACK_TO_FOCUS`)

**Problem:** Clicking **"Return to Productive Tab"** on the L3 Full Shield Blocker always opened a **new empty browser tab** instead of switching to an existing productive tab.

**Root cause:** `NAVIGATE_BACK_TO_FOCUS` in `service-worker.js` fell through to `chrome.tabs.create({})` whenever `session.last_productive_tab_id` was `null`. This value is `null` at session start and only gets populated after the user first navigates to a non-distracting site — so on fresh sessions the fallback always fired.

**Fix — three-priority resolution order:**

| Priority | Condition | Action |
|---|---|---|
| 1st | `last_productive_tab_id` is set and tab still open | `chrome.tabs.update(id, { active: true })` + bring window to foreground |
| 2nd | No stored productive tab, or it was closed | Scan all open tabs via `chrome.tabs.query({})`, pick first non-distracting hostname |
| 3rd | Every open tab is on a distracting site | Fall back to `chrome.tabs.create({})` (new tab) as last resort |

The tab scan uses the same `isDistracting(host, distractionList)` helper already used by the state machine, so it respects the active session's distraction list exactly.

---

#### 🪵 Extension Structured Logging (`logger.js`)

- **`logger.js`** (`src/shared/logger.js`) — Created Python-style logger module with levels `DEBUG`, `INFO`, `WARN`, `ERROR`, millisecond timestamps, and subsystem tags (`[SW]`, `[SM]`, `[ACT]`, `[DB-SYNC]`):
  - Format: `[FE <LEVEL>] [<TAG>] HH:mm:ss.ms → <MESSAGE>`
  - Integrated into:
    - **`service-worker.js`** — all transitions, tab scans, navigation events, action executions, and error captures now emit timestamped logs.
    - **`database-sync.js`** — offline queue depth, Supabase PostgREST sync attempts, FastAPI batch sync fallbacks, and parent row assertions now log clearly.

---

## Previous Sessions

### [2026-10-23] — Browser Extension Phases 1–4 complete

- **EXT-1:** Service Worker + State Machine — 9/9 live Chrome checks pass
- **EXT-2:** In-Page Overlays — Shadow DOM, L1 Toast, L2 Friction Modal, L3 Full Shield
- **EXT-3:** Popup UI — dark-mode, session status, start/stop, sync pill
- **EXT-4:** Web Dashboard Bridge + Cloud DB Sync — `bridge.js` postMessage, `database-sync.js` Supabase writes, offline queue + retry

### [2026-10-25 morning] — Web production build, Realtime feed, auth

- **WEB-1:** Flutter web production build (`flutter build web --release --dart-define`) verified
- **Live Feed:** `watchDistractionEvents()` Realtime stream, `liveDistractionFeed` state, slide-in animated `LiveDistractionFeed` widget
- **AUTH-1:** Supabase Anonymous Auth (`signInAnonymously()` on first launch)
- **AUTH-2:** Email OTP Login flow (anonymous → linked account, same `auth.uid()` preserved)
- **DB-1–4:** Dual-layer SQLite + Supabase, RLS policies, 7-day rolling session window, migration on login

---

## Known Issues / Next Steps

| Area | Issue | Priority |
|---|---|---|
| Web | `focus_sessions` may not appear if extension inserts with a different `user_id` than current web auth | High |
| Web | `users` table profile row may not exist for new OTP accounts (synthesised from `user_xp` as workaround) | Medium |
| Extension | `last_productive_tab_id` is never set if session is started with no non-distracting tab open | Low |
| Mobile | CI/CD pipeline (`MOB-6`) still failing on GitHub Actions (Gradle/AGP version mismatch) | Medium |
| Backend | `BE-3/BE-4` endpoints unverified with live traffic | Medium |
