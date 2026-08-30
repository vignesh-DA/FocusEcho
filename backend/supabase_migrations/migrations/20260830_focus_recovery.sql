-- FocusEcho Focus Recovery Enhancement (Features 1-4).
-- Additive and safe to apply after the Sprint 2 + intelligence-foundation schemas.
--
-- Feature 1 — Focus Intent: every session carries a stated goal.
alter table public.focus_sessions
  add column if not exists intent text not null default '';

-- Feature 2 — Escalating Intervention log. One row per intervention shown,
-- dismissed, or acted upon (level 1 heads-up, 2-3 full-screen, 4+ forced).
create table if not exists public.intervention_events (
  id uuid primary key,
  session_id uuid not null references public.focus_sessions(id) on delete cascade,
  level integer not null check (level between 1 and 4),
  action_taken text not null,
  timestamp timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists idx_intervention_events_session_time
  on public.intervention_events(session_id, timestamp desc);

alter table public.intervention_events enable row level security;
create policy "intervention events: own rows" on public.intervention_events
  for all using (
    exists (
      select 1 from public.focus_sessions s
      where s.id = intervention_events.session_id and s.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.focus_sessions s
      where s.id = intervention_events.session_id and s.user_id = auth.uid()
    )
  );

-- Feature 2 — escalation level travels with distraction events so the web
-- client and analytics can reconstruct the intervention ladder.
alter table public.distraction_events
  add column if not exists escalation_level integer not null default 1;

-- Feature 3 — Recovery Rate.
-- NOTE: the requested `returned_at` timestamp is already modelled by the
-- existing `recovered_at` column (with `recovery_time_seconds` as the derived
-- delta), so no duplicate column is added. Recovery backfill relies on
-- upserts: clients re-push a recovered row (is_recovered/recovered_at set)
-- and the upsert overwrites the earlier partial row.

create index if not exists idx_distraction_events_recovered
  on public.distraction_events(session_id, recovered_at);

-- Feature 4 — cross-surface nudges use Supabase Realtime broadcast channels
-- (no persistent schema). Broadcasts are authorized for any authenticated
-- client of the same channel; the anon key already gates channel access.