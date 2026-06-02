# Focus Echo AI Architecture

## System Overview
```
 Android App Switch
       |
       v
 FocusDetectionService/Kotlin --> EventChannel --> Flutter FocusSession VM
       |                                      |
       v                                      v
  Local SQLite (write-first) ---------> Dashboard / Analytics UI
       |
       v
   SyncService ---> Supabase ---> FastAPI ---> ScoringService/RuleEngine
```

## Flutter MVVM Layers
```
 Screens (StatelessWidget)
        |
        v
 ViewModels (StateNotifier)
        |
        v
 Repositories/Services (Sync, Supabase)
        |
        v
 Local DB DAOs + Platform Channels
```

## Android Native Detection Flow
1. Session starts via MethodChannel `focus_echo/session`.
2. Foreground service polls recent UsageStats every second.
3. Non-productive package triggers distraction event payload.
4. EventChannel streams payload to Flutter.
5. Flutter records event and opens alert modal.

## SQLite -> Supabase Sync
1. Events/sessions are always inserted in SQLite first.
2. Unsynced rows are queued when cloud sync is enabled.
3. Periodic sync checks connectivity and pushes queue to Supabase.
4. Successfully pushed records are marked synced.

## Rule Engine Decision Tree
1. No recent events -> SAFE  
2. >3 events in 30 min -> HIGH  
3. Same package repeated >2 times -> CRITICAL  
4. Latest recovery >10s -> MEDIUM  
5. Single fast recovery -> LOW

## API Endpoints
| Endpoint | Method | Purpose |
|---|---|---|
| `/health` | GET | Service health |
| `/api/v1/events/batch` | POST | Upsert event batch |
| `/api/v1/events/{session_id}` | GET | Get session events |
| `/api/v1/events/{event_id}/recover` | POST | Mark event recovered |
| `/api/v1/analytics/summary/{user_id}` | GET | Weekly summary |
| `/api/v1/analytics/sessions/{user_id}` | GET | Last 30 sessions |
| `/api/v1/analytics/risk-trend/{user_id}` | GET | 14-day risk trend |
| `/api/v1/scoring/session/{session_id}` | POST | Session scoring |

## End-to-End Data Flow
1. User switches away from productive app.
2. Kotlin service emits distraction payload.
3. Flutter VM stores event in SQLite and computes risk.
4. Alert modal runs recovery countdown and updates XP.
5. Session stop computes focus score and persists summary.
6. Dashboard and analytics aggregate from local DB.
7. Sync service pushes to Supabase for backend analytics APIs.
