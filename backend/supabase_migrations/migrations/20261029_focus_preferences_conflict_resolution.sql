-- Resolve cross-device focus preference edits in one database transaction.
-- A strictly newer client edit wins. Equal timestamps preserve the existing
-- server row, so the resolution is deterministic across devices.

CREATE OR REPLACE FUNCTION public.sync_user_focus_preferences(
  p_productive_apps JSONB,
  p_distracting_apps JSONB,
  p_web_distracting_sites JSONB,
  p_app_time_limits_seconds JSONB,
  p_updated_at TIMESTAMPTZ
)
RETURNS SETOF public.user_focus_preferences
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, auth
AS $$
DECLARE
  resolved public.user_focus_preferences%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.user_focus_preferences AS current (
    user_id,
    productive_apps,
    distracting_apps,
    web_distracting_sites,
    app_time_limits_seconds,
    updated_at
  )
  VALUES (
    auth.uid(),
    COALESCE(p_productive_apps, '[]'::JSONB),
    COALESCE(p_distracting_apps, '[]'::JSONB),
    COALESCE(p_web_distracting_sites, '[]'::JSONB),
    COALESCE(p_app_time_limits_seconds, '{}'::JSONB),
    COALESCE(p_updated_at, now())
  )
  ON CONFLICT (user_id) DO UPDATE SET
    productive_apps = EXCLUDED.productive_apps,
    distracting_apps = EXCLUDED.distracting_apps,
    web_distracting_sites = EXCLUDED.web_distracting_sites,
    app_time_limits_seconds = EXCLUDED.app_time_limits_seconds,
    updated_at = EXCLUDED.updated_at
  WHERE current.updated_at < EXCLUDED.updated_at
  RETURNING * INTO resolved;

  IF NOT FOUND THEN
    SELECT * INTO resolved
    FROM public.user_focus_preferences
    WHERE user_id = auth.uid();
  END IF;

  RETURN NEXT resolved;
END;
$$;

REVOKE ALL ON FUNCTION public.sync_user_focus_preferences(
  JSONB, JSONB, JSONB, JSONB, TIMESTAMPTZ
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sync_user_focus_preferences(
  JSONB, JSONB, JSONB, JSONB, TIMESTAMPTZ
) TO authenticated;

COMMENT ON FUNCTION public.sync_user_focus_preferences(
  JSONB, JSONB, JSONB, JSONB, TIMESTAMPTZ
) IS 'Atomically applies strictly newer per-user settings; equal timestamps keep the existing server row.';

NOTIFY pgrst, 'reload schema';
