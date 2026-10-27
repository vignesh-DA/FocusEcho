-- Repair the policy name after deploying the 20261023 anonymous-auth RLS set.
DROP POLICY IF EXISTS focuecho_interventions_insert ON public.intervention_events;
DROP POLICY IF EXISTS focusecho_interventions_insert ON public.intervention_events;
CREATE POLICY focusecho_interventions_insert ON public.intervention_events
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.focus_sessions s
      WHERE s.id = session_id AND s.user_id = auth.uid()
    )
  );
