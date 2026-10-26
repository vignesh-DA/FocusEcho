# FocusEcho — Boss Prompt: AI Focus Coach ("EchoCoach")

## Context & Objectives
You are a senior full-stack AI engineer working on **FocusEcho**, a cross-platform focus and productivity ecosystem (Flutter mobile/web, Chrome extension, FastAPI backend, Supabase database).
The workspace root is `e:\Project\FocusEcho\`.

FocusEcho currently tracks focus sessions, records distraction events across native apps (Android) and browser tabs (Chrome Extension), and displays live feeds and summaries.
Now, we are building **EchoCoach — The AI Focus Coach**, transforming FocusEcho from a passive tracker into an active, intelligent behavioral guide that helps users enter, sustain, and reflect on deep work sessions.

---

## The 4-Tier AI Coaching Loop

```
┌─────────────────────────────────────────────────────────────┐
│ 1. PRE-SESSION: Intention Refinement & Priming              │
│    - Analyze user's raw intention ("work on thesis")        │
│    - Prompt for SMART definition & tangible deliverable     │
│    - Provide pre-emptive caution based on past session traps│
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. IN-SESSION: Contextual Real-Time Micro-Nudges            │
│    - When Level 1 / Level 2 distraction alert triggers       │
│    - Tailored nudge reminding user of stated intention      │
│    - Micro-coaching: 3-breath grounding, friction injection │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. POST-SESSION: AI Debrief & Pattern Discovery             │
│    - Embedded directly into SessionSummaryScreen             │
│    - Diagnoses cognitive drop-off points (e.g. 18m fatigue) │
│    - Delivers 1 tangible micro-experiment for next session  │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. LONGITUDINAL: Weekly Focus Diagnosis & Circadian Audit   │
│    - Peak flow hours identification                         │
│    - Primary dopamine escape-hatch analysis                 │
│    - Focus stamina trajectory (XP & streak correlation)     │
└─────────────────────────────────────────────────────────────┘
```

---

## Non-Negotiable Privacy & Architectural Constraints

1. **Strict Zero-Content Privacy Policy**:
   - NEVER send browser URL paths, page DOM, email text, search queries, or document contents to any LLM.
   - The LLM ONLY sees anonymized, aggregated metadata:
     - High-level domain/app label (e.g., `youtube.com`, `instagram.com`, `VS Code`)
     - Session elapsed seconds and total duration
     - Intention string entered by user
     - Recovery speed (in seconds)
     - Time-of-day / Day-of-week
2. **Provider Agnostic with Graceful Fallback**:
   - Backend calls Google Gemini (or OpenAI / Anthropic) using structured JSON output.
   - If API keys are missing, network is offline, or rate limits occur, fallback seamlessly to **heuristic rule-based coaching cards** (never throw exceptions or break UI).
3. **Restrained, Non-Intrusive UX**:
   - The AI Coach should never be chatty or spam notifications. Max 1-2 sentences per nudge.
   - Follow FocusEcho's existing design system in `AppColors` and `AppDecorations.glassmorphismCard()`.
4. **Platform Compatibility**:
   - Must run flawlessly on Flutter Web and Android. Guard native calls with `kIsWeb`.
   - Browser extension displays coaching nudges on L1 toast and L2 overlay.

---

## Component Architecture & File Plan

| Layer | File / Location | Responsibility |
|---|---|---|
| **Database** | `backend/supabase_migrations/005_ai_coach.sql` | `coach_profiles` and `coach_insights` tables + RLS policies |
| **Backend API** | `backend/app/services/ai_coach_service.py` | LLM prompt engineering, Gemini API client, heuristic fallbacks |
| **Backend Routes**| `backend/app/api/routes/coach.py` | REST endpoints: `/refine-intention`, `/session-debrief`, `/micro-nudge` |
| **Backend Schemas**| `backend/app/schemas/coach.py` | Pydantic input/output schemas |
| **Mobile Service**| `mobile_app/lib/services/ai_coach_service.dart` | HTTP/Supabase client fetching coach responses |
| **Mobile State** | `mobile_app/lib/features/ai_coach/ai_coach_state.dart` | Riverpod models for intention refinement, debriefs & persona |
| **Mobile UI** | `mobile_app/lib/features/ai_coach/widgets/` | `CoachIntentionBar`, `CoachDebriefCard`, `CoachNudgeModal` |
| **Summary Screen**| `mobile_app/lib/features/focus_session/session_summary_screen.dart` | Mounts `CoachDebriefCard` seamlessly |
| **Extension** | `browser_extension/src/background/service-worker.js` | Uses dynamic coach copy in L1 toasts / L2 overlays |

---

## Detailed Implementation Steps

### STEP 1: Supabase Database Migration
Create `backend/supabase_migrations/005_ai_coach.sql`:

```sql
-- 1. Coach Preferences per User
CREATE TABLE IF NOT EXISTS public.coach_profiles (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    persona VARCHAR(32) DEFAULT 'balanced' CHECK (persona IN ('disciplined', 'balanced', 'gentle', 'analytical')),
    strictness_level INT DEFAULT 3 CHECK (strictness_level BETWEEN 1 AND 5),
    enable_pre_session_coaching BOOLEAN DEFAULT true,
    enable_in_session_nudges BOOLEAN DEFAULT true,
    enable_post_session_debrief BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Coach Insights & Session Debriefs
CREATE TABLE IF NOT EXISTS public.coach_insights (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    session_id UUID REFERENCES public.focus_sessions(id) ON DELETE CASCADE,
    insight_type VARCHAR(32) NOT NULL CHECK (insight_type IN ('intention_refinement', 'in_session_nudge', 'session_debrief', 'weekly_diagnosis')),
    headline VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    actionable_tip TEXT,
    user_feedback INT DEFAULT 0 CHECK (user_feedback BETWEEN -1 AND 1), -- -1 = unhelpful, 0 = neutral, 1 = helpful
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS
ALTER TABLE public.coach_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coach_insights ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their coach profile"
    ON public.coach_profiles FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view and update their coach insights"
    ON public.coach_insights FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
```

---

### STEP 2: FastAPI Backend Engine

#### 1. Schemas (`backend/app/schemas/coach.py`)
```python
from pydantic import BaseModel, Field
from typing import Optional, List

class IntentionRefineRequest(BaseModel):
    user_id: Optional[str] = None
    raw_intention: str = Field(..., min_length=2, max_length=200)
    target_duration_minutes: int = 25
    persona: str = "balanced"

class IntentionRefineResponse(BaseModel):
    is_sufficiently_clear: bool
    refined_intention: str
    clarity_score: int # 1 to 100
    coach_feedback: str
    suggested_deliverable: str

class SessionDebriefRequest(BaseModel):
    user_id: Optional[str] = None
    session_id: Optional[str] = None
    intention: str
    duration_seconds: int
    focus_score: int
    distraction_count: int
    median_recovery_seconds: int
    top_distractions: List[str] = []
    persona: str = "balanced"

class SessionDebriefResponse(BaseModel):
    headline: str
    score_analysis: str
    fatigue_point_detected: Optional[str] = None
    actionable_experiment: str
    xp_cheer: str
```

#### 2. Service (`backend/app/services/ai_coach_service.py`)
- Implement `AiCoachService` using `google-genai` (Gemini 2.5 Flash / 1.5 Pro) or structured prompts.
- Implement robust fallbacks:
  - If intention < 4 words: suggest adding measurable output.
  - If focus_score > 85: praise flow maintenance.
  - If focus_score < 60: diagnose distraction triggers without guilt/shame.

#### 3. Route (`backend/app/api/routes/coach.py`)
- Expose POST `/api/coach/refine-intention`
- Expose POST `/api/coach/session-debrief`
- Expose POST `/api/coach/feedback`

Register in `backend/app/main.py`:
```python
from app.api.routes import coach
app.include_router(coach.router, prefix="/api/coach", tags=["AI Coach"])
```

---

### STEP 3: Flutter Mobile & Web Client

#### 1. Add Service (`mobile_app/lib/services/ai_coach_service.dart`)
- Calls backend `/api/coach/*` when available, with direct offline fallback if offline or backend is unreachable.
- Syncs insight feedback to Supabase table `coach_insights`.

#### 2. Pre-Session Intention Refiner Widget
- In `focus_session_screen.dart` (or start modal):
  - Next to intention textfield, add an AI Sparkle icon: "Refine with AI Coach".
  - Shows 1-tap replacement chip with SMART intention (e.g. "Draft 2 pages of documentation" instead of "work").

#### 3. Session Summary Debrief Integration
- In `mobile_app/lib/features/focus_session/session_summary_screen.dart`:
  - Mount a new `CoachDebriefCard`:
    - Clean glassmorphism styling (`AppColors.surfaceCard`, `AppColors.primaryTeal` accent)
    - Animated entrance (fade + subtle slide)
    - Headline: e.g. *"Great flow in the first 20 minutes, minor fatigue near the end"*
    - Actionable Micro-Experiment: *"For your next 45m block, take a 2-minute physical stretch at minute 25."*
    - Quick thumbs-up / thumbs-down buttons to train the coach.

#### 4. Settings Screen: Coach Persona Selector
- In `mobile_app/lib/features/settings/settings_screen.dart`:
  - Add Coach Persona section:
    - ⚡ **Disciplined (Jocko / Stoic)**: Direct, no excuses, high accountability.
    - 🌿 **Supportive (Mentor)**: Empathetic, encouraging, psychological safety.
    - 🔬 **Analytical (Scientist)**: Data-first, focuses on cognitive metrics and circadian rhythms.

---

### STEP 4: Chrome Extension Micro-Nudge Integration
- In `browser_extension/src/background/service-worker.js`:
  - When triggering L1 Toast or L2 Intervention Overlay, pass the active intention:
    * *"Remember your goal: '{intention}'. Close this tab and protect your streak."*
  - Add coach-driven friction messages dynamically configured from coach settings.

---

## Verification & Acceptance Criteria

1. **Intention Refinement Test**:
   - Entering `"stuff"` triggers a prompt suggesting a specific, actionable deliverable.
   - Entering `"Review PR #42 and write tests"` receives high clarity score without unnecessary nagging.
2. **Offline Resilience Test**:
   - Disconnect network; verify UI shows local heuristic coach cards without crashing or hanging.
3. **Session Summary Integration**:
   - Complete a 5-minute test session with 2 distractions. Verify `SessionSummaryScreen` renders the `CoachDebriefCard` with non-zero metrics and feedback buttons.
4. **Data Privacy Check**:
   - Inspect network payloads in Chrome DevTools / logging; confirm no private URLs or tab content are transmitted.

---
*Ready to execute: Feed this prompt into the agent to build the full AI Focus Coach stack.*
