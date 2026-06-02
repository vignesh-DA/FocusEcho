# ⚡ FocusEcho AI

FocusEcho AI is a **real-time focus recovery and digital productivity platform**. By combining on-device background detection with server-side machine learning and rule-based analytics, FocusEcho detects distracting app switches the moment they happen, nudges the user to recover focus, and rewards positive habits.

---

## 🚀 Key Features

*   **⚡ Real-Time App-Switch Detection**: Runs a background Kotlin Foreground & Accessibility service (polling at 3s for battery optimization) to monitor active package states.
*   **🎯 Interactive Focus Recovery Alerts**: Displays a non-judgmental alert modal with a 10-second countdown when a distraction app is opened.
*   **⚖️ Rule-Engine Risk Scoring**: Dynamically calculates distraction risk scores (`LOW`, `MEDIUM`, `HIGH`, `CRITICAL`) using recent event density and app categories.
*   **🎮 Habit Gamification**: Tracks daily focus streaks and awards Experience Points (XP) for rapid recovery.
*   **📊 Analytics & Dashboards**: Displays detailed historical analysis and 14-day daily focus trends.
*   **☁️ Offline-First Cloud Sync**: Persists data to a local SQLite database and periodically synchronizes to Supabase with automatic connection checking and exponential backoff retry.
*   **🔒 Authentication & Privacy**: Integrated Google OAuth 2.0 with guest session migration and GDPR-compliant "Delete My Data" options.

---

## 🏗️ System Architecture

```
                                  [ ANDROID DEVICE ]
   ┌────────────────────────────────────────────────────────────────────────┐
   │  Kotlin Native Service  ──(EventChannel)──▶  Flutter MVVM Layer        │
   │  (UsageStats Poller)                       (StateNotifier / Riverpod)  │
   │           │                                             │              │
   │           ▼                                             ▼              │
   │  DistractionEventQueue                               SQLite DB         │
   └─────────────────────────────────────────────────────────┬──────────────┘
                                                             │
                                                      (SyncService)
                                                             │ (HTTPS)
                                                             ▼
                                                    [ SUPABASE CLOUD ]
                                                  (Postgres + Google Auth)
                                                             │
                                                             ▼
                                                    [ FASTAPI BACKEND ]
                                                  (Render Web + Docker)
```

---

## 🌐 Interactive Web Showcase & Demo

Because Android native background services cannot run in standard web browsers, FocusEcho AI features a **Web Showcase Prototype**. The app compiles directly to Web and includes:
1.  **In-Memory SQLite Mocking**: Simulates SQLite locally in browser memory to prevent sqflite crashes.
2.  **Interactive Distraction Simulator**: Includes a **"Simulate Distraction"** button on the active focus screen, allowing evaluators to experience the full alert, recovery, scoring, and cloud synchronization flows directly in a web browser without installing an APK.

---

## 🛠️ Project Structure

```
├── .github/workflows/   # Automated CI/CD pipelines (APK releases)
├── backend/             # FastAPI scoring & analytics service (Python)
│   ├── app/             # REST endpoints, schemas, and scoring engine
│   └── supabase/        # Database schema migrations and SQL scripts
├── docs/                # Cloud engineering architecture and test workbooks
├── mobile_app/          # Flutter multi-platform mobile application (Dart/Kotlin)
│   ├── android/         # Native Android source code and platform channels
│   └── lib/             # Core themes, routers, local DB, and feature viewmodels
└── render.yaml          # Render Blueprint deployment definition
```

---

## ⚙️ Prerequisites

Ensure you have the following installed locally:
*   [Flutter SDK](https://docs.flutter.dev/get-started/install) `3.19+`
*   [Dart SDK](https://dart.dev/get-started) `3.3+`
*   [Python](https://www.python.org/downloads/) `3.10+`
*   [Docker Desktop](https://www.docker.com/products/docker-desktop/) (optional, for backend containerization)

---

## 🚀 Quick Start Guide

### 1. Set Up the Mobile App

1.  Navigate into the mobile app directory:
    ```bash
    cd mobile_app
    ```
2.  Fetch packages:
    ```bash
    flutter pub get
    ```
3.  Run the code generators:
    ```bash
    flutter pub run build_runner build --delete-conflicting-outputs
    ```
4.  **Run on Android (Physical Device)**:
    Ensure USB debugging is enabled, connect your device, and execute:
    ```bash
    flutter run
    ```
5.  **Compile and Run for Web**:
    To launch the interactive demo in your web browser:
    ```bash
    flutter run -d chrome
    ```

---

### 2. Set Up the Backend API

#### Option A: Python Virtual Environment (Local)
1.  Navigate to the backend folder:
    ```bash
    cd backend
    ```
2.  Create and activate a virtual environment:
    ```bash
    # Windows
    python -m venv venv
    venv\Scripts\activate
    
    # macOS/Linux
    python3 -m venv venv
    source venv/bin/activate
    ```
3.  Install dependencies:
    ```bash
    pip install -r requirements.txt
    ```
4.  Configure environment:
    Copy `.env.example` to `.env` and fill in your Supabase connection strings.
5.  Launch the hot-reloading development server:
    ```bash
    uvicorn app.main:app --reload
    ```
    Access the interactive API documentation at: `http://localhost:8000/docs`

#### Option B: Docker Compose
Build and start the containerized backend:
```bash
docker compose up --build
```

---

## 📦 Deployment Commands

### Web App Compilation
Build static files for Vercel/Netlify hosting:
```bash
cd mobile_app
flutter build web --release
```

### Manual Android APK Build
Build the release APK for manual installation:
```bash
cd mobile_app
flutter build apk --release
```

---

## 🤖 Continuous Integration & CD

This project uses **GitHub Actions** for automated builds and releases.
*   **Trigger**: Create and push a version tag (e.g., `git tag v1.0.0 && git push origin v1.0.0`).
*   **Result**: The GitHub Actions runner compiles the optimized production APK and attaches `FocusEchoAI-release.apk` directly to a newly published GitHub Release.
