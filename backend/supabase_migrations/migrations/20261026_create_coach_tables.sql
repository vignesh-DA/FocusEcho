-- ============================================================================
-- Migration: 20261026_create_coach_tables.sql
-- Description: EchoCoach v1 schema: coach_profiles and coach_insights tables
-- Security: Strict RLS — users can SELECT own insights and UPDATE user_feedback only.
--           Inserts to coach_insights are restricted to service_role (backend).
-- ============================================================================

-- 1. Coach user preferences & opt-in status
CREATE TABLE IF NOT EXISTS public.coach_profiles (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    is_opted_in BOOLEAN NOT NULL DEFAULT false,
    opted_in_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Coach insights (post-session debriefs & intention refinements)
-- Verified: focus_sessions(id) is UUID in public.focus_sessions
CREATE TABLE IF NOT EXISTS public.coach_insights (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    session_id UUID REFERENCES public.focus_sessions(id) ON DELETE CASCADE,
    insight_type TEXT NOT NULL CHECK (insight_type IN ('intention_refinement', 'session_debrief')),
    headline TEXT NOT NULL,
    body TEXT NOT NULL,
    actionable_tip TEXT,
    distraction_offsets_json JSONB DEFAULT '[]'::jsonb,
    user_feedback SMALLINT DEFAULT 0 CHECK (user_feedback BETWEEN -1 AND 1),
    is_fallback BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create indexes for performance and session lookup
CREATE INDEX IF NOT EXISTS idx_coach_insights_session_user
    ON public.coach_insights(session_id, user_id);

CREATE INDEX IF NOT EXISTS idx_coach_insights_user_created
    ON public.coach_insights(user_id, created_at DESC);

-- Enable Row Level Security (RLS)
ALTER TABLE public.coach_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coach_insights ENABLE ROW LEVEL SECURITY;

-- ── RLS: coach_profiles ──────────────────────────────────────────────
-- Users can read, insert, and update their own opt-in status.
DROP POLICY IF EXISTS coach_profiles_select_own ON public.coach_profiles;
CREATE POLICY coach_profiles_select_own ON public.coach_profiles
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS coach_profiles_insert_own ON public.coach_profiles;
CREATE POLICY coach_profiles_insert_own ON public.coach_profiles
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS coach_profiles_update_own ON public.coach_profiles;
CREATE POLICY coach_profiles_update_own ON public.coach_profiles
    FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS coach_profiles_delete_own ON public.coach_profiles;
CREATE POLICY coach_profiles_delete_own ON public.coach_profiles
    FOR DELETE USING (auth.uid() = user_id);

-- ── RLS: coach_insights ──────────────────────────────────────────────
-- Requirement: Only the backend inserts coach_insights (via service_role key).
-- Users can SELECT their own insights and UPDATE user_feedback only.
-- Users CANNOT INSERT or DELETE insights directly.
DROP POLICY IF EXISTS coach_insights_select_own ON public.coach_insights;
CREATE POLICY coach_insights_select_own ON public.coach_insights
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS coach_insights_update_feedback ON public.coach_insights;
CREATE POLICY coach_insights_update_feedback ON public.coach_insights
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS coach_insights_delete_own ON public.coach_insights;
CREATE POLICY coach_insights_delete_own ON public.coach_insights
    FOR DELETE USING (auth.uid() = user_id);

-- Service role bypasses RLS automatically, ensuring backend can INSERT insights.
