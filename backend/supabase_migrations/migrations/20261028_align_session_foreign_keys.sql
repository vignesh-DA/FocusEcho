-- Keep session foreign-key columns compatible with both historical FocusEcho
-- base schemas (text IDs and UUID IDs). New installations use UUID IDs in
-- 001_initial_schema.sql; this migration safely repairs older installations.
DO $$
DECLARE
  parent_type TEXT;
  child_table TEXT;
  child_type TEXT;
  constraint_row RECORD;
  child_tables TEXT[] := ARRAY[
    'distraction_events',
    'intervention_events',
    'coach_insights'
  ];
BEGIN
  SELECT format_type(a.atttypid, a.atttypmod)
    INTO parent_type
    FROM pg_attribute a
    WHERE a.attrelid = 'public.focus_sessions'::regclass
      AND a.attname = 'id'
      AND NOT a.attisdropped;

  IF parent_type IS NULL THEN
    RAISE EXCEPTION 'public.focus_sessions.id was not found';
  END IF;

  FOREACH child_table IN ARRAY child_tables LOOP
    IF to_regclass(format('public.%I', child_table)) IS NULL THEN
      CONTINUE;
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM pg_attribute
      WHERE attrelid = format('public.%I', child_table)::regclass
        AND attname = 'session_id'
        AND NOT attisdropped
    ) THEN
      CONTINUE;
    END IF;

    SELECT format_type(a.atttypid, a.atttypmod)
      INTO child_type
      FROM pg_attribute a
      WHERE a.attrelid = format('public.%I', child_table)::regclass
        AND a.attname = 'session_id'
        AND NOT a.attisdropped;

    IF child_type IS DISTINCT FROM parent_type THEN
      FOR constraint_row IN
        SELECT conname
        FROM pg_constraint
        WHERE conrelid = format('public.%I', child_table)::regclass
          AND confrelid = 'public.focus_sessions'::regclass
      LOOP
        EXECUTE format('ALTER TABLE public.%I DROP CONSTRAINT %I', child_table, constraint_row.conname);
      END LOOP;

      EXECUTE format(
        'ALTER TABLE public.%I ALTER COLUMN session_id TYPE %s USING session_id::text::%s',
        child_table,
        parent_type,
        parent_type
      );
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM pg_constraint c
      JOIN pg_attribute a
        ON a.attrelid = c.conrelid AND a.attnum = ANY(c.conkey)
      WHERE c.conrelid = format('public.%I', child_table)::regclass
        AND c.confrelid = 'public.focus_sessions'::regclass
        AND c.contype = 'f'
        AND a.attname = 'session_id'
    ) THEN
      EXECUTE format(
        'ALTER TABLE public.%I ADD CONSTRAINT %I FOREIGN KEY (session_id) REFERENCES public.focus_sessions(id) ON DELETE CASCADE',
        child_table,
        child_table || '_session_id_focus_sessions_fkey'
      );
    END IF;
  END LOOP;
END
$$;

-- RLS restricts which coach insight rows can be changed. Limit authenticated
-- users to the single feedback field as well.
REVOKE UPDATE ON public.coach_insights FROM authenticated;
GRANT UPDATE (user_feedback) ON public.coach_insights TO authenticated;
