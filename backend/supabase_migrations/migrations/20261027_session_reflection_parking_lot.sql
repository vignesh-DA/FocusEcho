-- Batch 1: optional session reflection and cross-surface parking lot.
-- Existing focus_sessions RLS policies continue to scope these fields through
-- the parent session row; no policy changes are required.

ALTER TABLE public.focus_sessions
  ADD COLUMN IF NOT EXISTS focus_rating INTEGER,
  ADD COLUMN IF NOT EXISTS drift_reason TEXT,
  ADD COLUMN IF NOT EXISTS parked_items JSONB;

CREATE OR REPLACE FUNCTION public.focusecho_valid_parked_items(value JSONB)
RETURNS BOOLEAN
LANGUAGE SQL
IMMUTABLE
AS $$
  SELECT value IS NULL
    OR (
      jsonb_typeof(value) = 'array'
      AND jsonb_array_length(value) <= 20
      AND NOT EXISTS (
        SELECT 1
        FROM jsonb_array_elements(value) AS item
        WHERE jsonb_typeof(item) <> 'string'
          OR char_length(item #>> '{}') > 120
      )
    );
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'focus_sessions_focus_rating_check'
  ) THEN
    ALTER TABLE public.focus_sessions
      ADD CONSTRAINT focus_sessions_focus_rating_check
      CHECK (focus_rating IS NULL OR focus_rating BETWEEN 1 AND 5);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'focus_sessions_drift_reason_check'
  ) THEN
    ALTER TABLE public.focus_sessions
      ADD CONSTRAINT focus_sessions_drift_reason_check
      CHECK (
        drift_reason IS NULL
        OR drift_reason IN ('bored', 'stuck', 'tired', 'notification', 'other')
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'focus_sessions_parked_items_check'
  ) THEN
    ALTER TABLE public.focus_sessions
      ADD CONSTRAINT focus_sessions_parked_items_check
      CHECK (public.focusecho_valid_parked_items(parked_items));
  END IF;
END
$$;
