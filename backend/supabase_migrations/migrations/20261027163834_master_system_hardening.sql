-- Align reflection fields, coach access policy, analytics RLS, and durable
-- coach request limits. This migration is additive and safe to re-run.

CREATE OR REPLACE FUNCTION public.focusecho_valid_parked_items(value JSONB)
RETURNS BOOLEAN
LANGUAGE SQL
IMMUTABLE
SET search_path = ''
AS $$
  SELECT value IS NULL
    OR (
      pg_catalog.jsonb_typeof(value) = 'array'
      AND pg_catalog.jsonb_array_length(value) <= 20
      AND NOT EXISTS (
        SELECT 1
        FROM pg_catalog.jsonb_array_elements(value) AS item
        WHERE pg_catalog.jsonb_typeof(item) <> 'string'
          OR pg_catalog.char_length(item #>> '{}') > 120
      )
    );
$$;

COMMENT ON FUNCTION public.focusecho_valid_parked_items(JSONB)
  IS 'Validates at most 20 parked-item strings of at most 120 characters; uses an empty search path.';

-- Product policy: users may read their insights and update feedback, but only
-- the backend service role may insert or delete insight rows.
DROP POLICY IF EXISTS coach_insights_delete_own ON public.coach_insights;
COMMENT ON TABLE public.coach_insights IS
  'Coach insight rows are inserted and deleted by the backend service role; users may read their own rows and update feedback.';

-- Reassert ownership checks on the existing analytics table policies.
ALTER TABLE public.nightly_analytics_summaries ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "nightly_summaries: select own" ON public.nightly_analytics_summaries;
CREATE POLICY "nightly_summaries: select own"
  ON public.nightly_analytics_summaries FOR SELECT
  USING ((SELECT auth.uid()) = user_id);
DROP POLICY IF EXISTS "nightly_summaries: insert own" ON public.nightly_analytics_summaries;
CREATE POLICY "nightly_summaries: insert own"
  ON public.nightly_analytics_summaries FOR INSERT
  WITH CHECK ((SELECT auth.uid()) = user_id);
DROP POLICY IF EXISTS "nightly_summaries: update own" ON public.nightly_analytics_summaries;
CREATE POLICY "nightly_summaries: update own"
  ON public.nightly_analytics_summaries FOR UPDATE
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE TABLE IF NOT EXISTS public.coach_daily_rate_limits (
  user_id UUID NOT NULL,
  usage_date DATE NOT NULL,
  request_count INTEGER NOT NULL CHECK (request_count BETWEEN 1 AND 30),
  PRIMARY KEY (user_id, usage_date)
);
ALTER TABLE public.coach_daily_rate_limits ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.coach_daily_rate_limits FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.coach_daily_rate_limits TO service_role;

CREATE OR REPLACE FUNCTION public.focusecho_consume_coach_daily_limit(
  p_user_id UUID,
  p_limit INTEGER
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  allowed BOOLEAN := FALSE;
  utc_day DATE := (pg_catalog.now() AT TIME ZONE 'UTC')::DATE;
BEGIN
  IF p_user_id IS NULL OR p_limit < 1 OR p_limit > 30 THEN
    RETURN FALSE;
  END IF;

  DELETE FROM public.coach_daily_rate_limits
    WHERE user_id = p_user_id AND usage_date < utc_day;

  INSERT INTO public.coach_daily_rate_limits AS existing (user_id, usage_date, request_count)
  VALUES (p_user_id, utc_day, 1)
  ON CONFLICT (user_id, usage_date) DO UPDATE
    SET request_count = existing.request_count + 1
    WHERE existing.request_count < p_limit
  RETURNING TRUE INTO allowed;

  RETURN COALESCE(allowed, FALSE);
END;
$$;

REVOKE ALL ON FUNCTION public.focusecho_consume_coach_daily_limit(UUID, INTEGER)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.focusecho_consume_coach_daily_limit(UUID, INTEGER)
  TO service_role;
COMMENT ON FUNCTION public.focusecho_consume_coach_daily_limit(UUID, INTEGER)
  IS 'Atomically consumes one UTC-day coach request allowance for a user; callable only by service_role.';

NOTIFY pgrst, 'reload schema';
