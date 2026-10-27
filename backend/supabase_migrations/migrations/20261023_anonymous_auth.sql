-- ═══════════════════════════════════════════════════════════════
-- FocusEcho — Production Migration
-- Applied on production database: 2026-10-25
-- Enables Anonymous Auth, creates missing tables/columns,
-- configures RLS policies for auth.uid() scoping, and enables Realtime.
-- ═══════════════════════════════════════════════════════════════

-- ── 1. Add missing columns ────────────────────────────────────
ALTER TABLE public.focus_sessions      ADD COLUMN IF NOT EXISTS intent    TEXT    DEFAULT 'Focus Session';
ALTER TABLE public.focus_sessions      ADD COLUMN IF NOT EXISTS is_synced INTEGER NOT NULL DEFAULT 1;
ALTER TABLE public.distraction_events  ADD COLUMN IF NOT EXISTS is_synced INTEGER NOT NULL DEFAULT 1;
ALTER TABLE public.distraction_events  ADD COLUMN IF NOT EXISTS is_recovered BOOLEAN DEFAULT FALSE;

-- ── 2. Create intervention_events if missing ──────────────────
DO $$
DECLARE
  session_id_type TEXT;
BEGIN
  SELECT format_type(a.atttypid, a.atttypmod)
    INTO session_id_type
    FROM pg_attribute a
    WHERE a.attrelid = 'public.focus_sessions'::regclass
      AND a.attname = 'id'
      AND NOT a.attisdropped;

  EXECUTE format(
    'CREATE TABLE IF NOT EXISTS public.intervention_events (
       id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
       session_id %s REFERENCES public.focus_sessions(id) ON DELETE CASCADE,
       timestamp TIMESTAMPTZ NOT NULL DEFAULT now(),
       level INTEGER NOT NULL DEFAULT 1,
       action_taken TEXT,
       is_synced INTEGER NOT NULL DEFAULT 1
     )',
    session_id_type
  );
END
$$;

-- ── 3. Enable RLS on all tables ───────────────────────────────
ALTER TABLE public.users               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_xp             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.focus_sessions      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.distraction_events  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.intervention_events ENABLE ROW LEVEL SECURITY;

-- ── 4. Drop all old policies cleanly ─────────────────────────
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT schemaname, tablename, policyname FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('users','user_xp','focus_sessions','distraction_events','intervention_events')
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', r.policyname, r.schemaname, r.tablename);
  END LOOP;
END;
$$;

-- ── 5. users policies ─────────────────────────────────────────
CREATE POLICY focusecho_users_select ON public.users FOR SELECT USING (auth.uid() = id);
CREATE POLICY focusecho_users_insert ON public.users FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY focusecho_users_update ON public.users FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
CREATE POLICY focusecho_users_delete ON public.users FOR DELETE USING (auth.uid() = id);

-- ── 6. user_xp policies ───────────────────────────────────────
CREATE POLICY focusecho_xp_select ON public.user_xp FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY focusecho_xp_insert ON public.user_xp FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY focusecho_xp_update ON public.user_xp FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY focusecho_xp_delete ON public.user_xp FOR DELETE USING (auth.uid() = user_id);

-- ── 7. focus_sessions policies ────────────────────────────────
CREATE POLICY focusecho_sessions_select ON public.focus_sessions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY focusecho_sessions_insert ON public.focus_sessions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY focusecho_sessions_update ON public.focus_sessions FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY focusecho_sessions_delete ON public.focus_sessions FOR DELETE USING (auth.uid() = user_id);

-- ── 8. distraction_events policies ───────────────────────────
CREATE POLICY focusecho_events_select ON public.distraction_events FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.focus_sessions s WHERE s.id = session_id AND s.user_id = auth.uid()));
CREATE POLICY focusecho_events_insert ON public.distraction_events FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM public.focus_sessions s WHERE s.id = session_id AND s.user_id = auth.uid()));
CREATE POLICY focusecho_events_update ON public.distraction_events FOR UPDATE
  USING (EXISTS (SELECT 1 FROM public.focus_sessions s WHERE s.id = session_id AND s.user_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.focus_sessions s WHERE s.id = session_id AND s.user_id = auth.uid()));
CREATE POLICY focusecho_events_delete ON public.distraction_events FOR DELETE USING (
  EXISTS (SELECT 1 FROM public.focus_sessions s WHERE s.id = session_id AND s.user_id = auth.uid()));

-- ── 9. intervention_events policies ──────────────────────────
CREATE POLICY focusecho_interventions_select ON public.intervention_events FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.focus_sessions s WHERE s.id = session_id AND s.user_id = auth.uid()));
CREATE POLICY focusecho_interventions_insert ON public.intervention_events FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM public.focus_sessions s WHERE s.id = session_id AND s.user_id = auth.uid()));
CREATE POLICY focusecho_interventions_update ON public.intervention_events FOR UPDATE
  USING (EXISTS (SELECT 1 FROM public.focus_sessions s WHERE s.id = session_id AND s.user_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.focus_sessions s WHERE s.id = session_id AND s.user_id = auth.uid()));
CREATE POLICY focusecho_interventions_delete ON public.intervention_events FOR DELETE USING (
  EXISTS (SELECT 1 FROM public.focus_sessions s WHERE s.id = session_id AND s.user_id = auth.uid()));

-- ── 10. Auto-create user profile + XP row on signup ──────────
CREATE OR REPLACE FUNCTION public.handle_auth_user_created()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.users (id, email, display_name)
  VALUES (
    new.id,
    coalesce(new.email, new.id::text || '@guest.local'),
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', 'FocusEcho user')
  )
  ON CONFLICT (id) DO UPDATE SET
    email        = excluded.email,
    display_name = excluded.display_name;

  INSERT INTO public.user_xp (user_id, total_xp, streak_days, updated_at)
  VALUES (new.id, 0, 0, now())
  ON CONFLICT (user_id) DO NOTHING;

  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created_focus_echo ON auth.users;
CREATE TRIGGER on_auth_user_created_focus_echo
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_auth_user_created();

-- ── 11. Realtime publication ──────────────────────────────────
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['focus_sessions','distraction_events','intervention_events','user_xp']
  LOOP
    BEGIN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
  END LOOP;
END;
$$;

-- ── 12. Backfill XP rows for existing auth users ──────────────
INSERT INTO public.user_xp (user_id, total_xp, streak_days, updated_at)
SELECT id, 0, 0, now() FROM auth.users
ON CONFLICT (user_id) DO NOTHING;
