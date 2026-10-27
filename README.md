# ⚡ FocusEcho AI

FocusEcho AI is a **real-time focus recovery, digital productivity, and behavioral coaching platform**. By combining on-device native monitoring across mobile and desktop with cloud synchronization and AI-driven coaching, FocusEcho detects distracting app and tab switches the moment they happen, delivers escalating nudges to recover focus, and rewards sustained deep work.

---

## 🚀 Key Features

*   **⚡ Real-Time App & Tab Detection**:
    *   **Android**: Low-battery 3-second native poller (`UsageStatsManager`) with continuous dwell tracking.
    *   **Web & Chrome Extension**: Manifest V3 service worker tracking tab switches with a state-machine ladder and shadow DOM overlays.
*   **🔔 Actionable Escalation Ladder & Repeating Nudges**:
    *   **Level 1 (Nudge)**: High-priority heads-up notification with one-tap return.
    *   **Level 2 (Warning)**: Notification with interactive action buttons (`[🎯 Return to Focus]` and `[☕ Take a Break]`).
    *   **Level 3 (Forced Choice / Lockout)**: Full-screen intervention and alarm-category alert.
    *   **Continuous Drift Nudges**: Fires repeating notifications every 30 seconds if the user remains inside a distracting app (*"Still on Instagram? 2m drift"*).
*   **🤖 EchoCoach — AI Focus Coach (Groq / Kimi)**:
    *   **Intention Refinement**: Pre-session debounced goal refiner.
    *   **Post-Session Debrief**: Analyzes session arithmetic, distraction timings, and median recovery speed.
    *   **Privacy Guarded**: Zero personal content sent to LLMs; cold-start protection (<5 sessions); deterministic rule-based offline fallback.
*   **🧠 Session Reflection & Parking Lot**:
    *   **Parking Lot**: Capture distracting thoughts or sudden to-dos into a bounded, searchable quick-list without breaking flow.
    *   **Post-Session Reflection**: Rate session focus (1–5 stars) and classify drift reasons (bored, stuck, tired, notification).
*   **📊 Next-Gen Glassmorphic Visualizations**:
    *   **Weekly Focus Time**: Interactive capsule rods with electric Indigo-to-Cyan gradients and daily target background tracks.
    *   **Daily Distractions**: Smooth curved sunset spline with glowing halo dots and ambient gradient fills.
    *   **Top Distracting Apps**: Neon contrast donut chart with frosted glass center metric and percentage bars.
    *   **14-Day Risk Trend**: Multi-color severity area wave with live risk status chips (`Low Risk`, `Moderate Risk`, `Elevated Risk`).
*   **🎮 Habit Gamification**: Daily streak tracking, rank titles (*Focus Rookie* ➔ *Zen Monk*), and dynamic XP progress calculation.
*   **☁️ Dual-Layer Offline-First Sync**: Local SQLite / Web Storage cache synchronizing seamlessly to Supabase Postgres with exponential backoff and Supabase Realtime broadcast.
*   **🔒 Frictionless Auth**: Anonymous one-click guest sessions with in-place Email OTP upgrade and local-to-cloud data migration.

---

## 🏗️ System Architecture

```text
 ┌───────────────────────────┐         ┌───────────────────────────┐
 │      ANDROID MOBILE       │         │     BROWSER EXTENSION     │
 │  Kotlin Foreground Poller │         │  Manifest V3 Background   │
 │   DistractionEventQueue   │         │    State Machine Engine   │
 └─────────────┬─────────────┘         └─────────────┬─────────────┘
               │                                     │
               ▼ (EventChannel)                      ▼ (Bridge / Realtime)
 ┌─────────────────────────────────────────────────────────────────┐
 │                       FLUTTER APP (UI)                          │
 │  • Riverpod State Management       • Glassmorphic Theme System  │
 │  • Dashboard & Focus Timer         • Next-Gen fl_chart Engine   │
 │  • Session Reflection & Parking    • EchoCoach Debrief Cards    │
 └─────────────────┬─────────────────────────────────┬─────────────┘
                   │                                 │
                   ▼ (SyncService)                   ▼ (REST)
       ┌────────────────────────┐        ┌────────────────────────┐
       │     SUPABASE CLOUD     │        │    FASTAPI BACKEND     │
       │   PostgreSQL Database  │◀──────▶│   Render Web Service   │
       │  Anonymous / OTP Auth  │        │   Groq EchoCoach SDK   │
       │  Realtime Publications │        │   Health & Analytics   │
       └────────────────────────┘        └────────────────────────┘
```

---

## 🛠️ Project Structure

```text
├── backend/                   # FastAPI REST API & EchoCoach Engine (Python)
│   ├── app/
│   │   ├── api/routes/        # Endpoints (sessions, coach, analytics, health)
│   │   ├── schemas/           # Pydantic schemas (coach, sessions, telemetry)
│   │   └── services/          # Groq SDK AI coach, scoring & intelligence engines
│   └── supabase_migrations/   # SQL migrations, RLS policies, and triggers
├── browser_extension/         # Manifest V3 Chrome Extension (JavaScript)
│   ├── src/background/        # Service worker, state machine & cloud sync
│   ├── src/content/           # Shadow DOM overlays (L1 toast, L2 modal, L3 block)
│   └── src/popup/             # Quick status popup UI
├── mobile_app/                # Flutter Cross-Platform Application (Android & Web)
│   ├── android/               # Kotlin native service, foreground poller, notifications
│   ├── lib/
│   │   ├── core/              # Theme tokens, router, AppConfig & constants
│   │   ├── features/          # Dashboard, Focus Session, Analytics, Coach, Auth
│   │   ├── local_db/          # SQLite DAOs (mobile) & WebStorage helpers
│   │   └── services/          # Supabase, SyncService, BrowserMonitor, FCM
│   └── test/                  # Automated unit and viewmodel test suites
├── docs/                      # Architecture workbooks, specifications & Boss Prompts
├── render.yaml                # Render cloud deployment blueprint
└── vercel.json                # Vercel deployment configuration for Flutter Web
```

---

## ⚙️ Prerequisites

*   [Flutter SDK](https://docs.flutter.dev/get-started/install) `3.19+`
*   [Dart SDK](https://dart.dev/get-started) `3.3+`
*   [Python](https://www.python.org/downloads/) `3.10+`
*   [Google Chrome](https://www.google.com/chrome/) or Chromium-based browser
*   [Supabase Account](https://supabase.com/) & [Groq Cloud API Key](https://console.groq.com/)

---

## 🚀 Quick Start Guide

### 1. Configure Credentials

Create a `dart_defines.json` file inside `mobile_app/` (or copy from root template):
```json
{
  "SUPABASE_URL": "https://<your-project-ref>.supabase.co",
  "SUPABASE_ANON_KEY": "<your-supabase-anon-key>",
  "BACKEND_URL": "https://<your-backend-host>"
}
```

---

### 2. Run the Flutter App

#### A. Web App (Local Chrome)
```bash
cd mobile_app
flutter pub get
flutter run -d chrome --web-port=3000 --dart-define-from-file=dart_defines.json
```
The web dashboard will be available at `http://localhost:3000`.

#### B. Android App (Physical Device or Emulator)
```bash
cd mobile_app
flutter run --dart-define-from-file=dart_defines.json
```

---

### 3. Load the Chrome Extension

1. Open Chrome and navigate to `chrome://extensions/`.
2. Toggle on **Developer mode** (top-right corner).
3. Click **Load unpacked** and select the `browser_extension` folder.
4. The FocusEcho icon will appear in your Chrome toolbar.

---

### 4. Run the Backend API Locally

```bash
cd backend
python -m venv venv

# Windows:
venv\Scripts\activate
# macOS/Linux:
source venv/bin/activate

pip install -r requirements.txt
cp .env.example .env
# Fill in your SUPABASE_SERVICE_ROLE_KEY, SUPABASE_JWT_SECRET, and GROQ_API_KEY in .env

uvicorn app.main:app --reload --port 8000
```
API Documentation (Swagger UI): `http://localhost:8000/docs`

---

### 5. Apply Supabase Database Migrations

Run the following migration files in the **Supabase SQL Editor** in sequence:
1. `backend/supabase_migrations/migrations/20261023_anonymous_auth.sql` — Anonymous auth trigger, RLS policies, core tables.
2. `backend/supabase_migrations/migrations/20261026_create_coach_tables.sql` — EchoCoach profiles and insights.
3. `backend/supabase_migrations/migrations/20261027_session_reflection_parking_lot.sql` — Parking lot and session reflections.

---

## 🧪 Testing & Verification

Run the comprehensive test suites across all project layers:

```bash
# Flutter Unit & ViewModel Tests (29 tests)
cd mobile_app
flutter test

# Backend Intelligence & EchoCoach Tests (17 tests)
cd ../backend
python -m unittest discover -s app/tests

# Chrome Extension State Machine Tests (149 tests)
cd ../browser_extension
node tests/state-machine.test.js
```

---

## 📦 Production Builds

```bash
# Compile Flutter Web for Vercel / Netlify
cd mobile_app
flutter build web --release --dart-define-from-file=dart_defines.json

# Compile Production Android APK
cd mobile_app
flutter build apk --release --dart-define-from-file=dart_defines.json
```
Output APK is located at: `mobile_app/build/app/outputs/flutter-apk/app-release.apk`
