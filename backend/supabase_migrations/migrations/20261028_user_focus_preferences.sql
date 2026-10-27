-- One account-scoped copy of app/site lists and per-app limits for mobile and
-- web clients. Local preferences remain the offline cache.
CREATE TABLE IF NOT EXISTS public.user_focus_preferences (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  productive_apps JSONB NOT NULL DEFAULT '[]'::jsonb,
  distracting_apps JSONB NOT NULL DEFAULT '[]'::jsonb,
  web_distracting_sites JSONB NOT NULL DEFAULT '[]'::jsonb,
  app_time_limits_seconds JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT focus_preferences_productive_array CHECK (jsonb_typeof(productive_apps) = 'array'),
  CONSTRAINT focus_preferences_distracting_array CHECK (jsonb_typeof(distracting_apps) = 'array'),
  CONSTRAINT focus_preferences_sites_array CHECK (jsonb_typeof(web_distracting_sites) = 'array'),
  CONSTRAINT focus_preferences_limits_object CHECK (jsonb_typeof(app_time_limits_seconds) = 'object')
);

ALTER TABLE public.user_focus_preferences ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS user_focus_preferences_select_own ON public.user_focus_preferences;
CREATE POLICY user_focus_preferences_select_own ON public.user_focus_preferences
  FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS user_focus_preferences_insert_own ON public.user_focus_preferences;
CREATE POLICY user_focus_preferences_insert_own ON public.user_focus_preferences
  FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS user_focus_preferences_update_own ON public.user_focus_preferences;
CREATE POLICY user_focus_preferences_update_own ON public.user_focus_preferences
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS user_focus_preferences_delete_own ON public.user_focus_preferences;
CREATE POLICY user_focus_preferences_delete_own ON public.user_focus_preferences
  FOR DELETE USING (auth.uid() = user_id);
