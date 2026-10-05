-- ============================================================
-- Migration: 002_rls_policies
-- Applied: 2026-10-03 (Phase 1 security hardening)
--
-- Enables Row Level Security on every table and adds per-user
-- read/write policies.  All policies require the caller to be
-- the owner of the row, identified by auth.uid().
-- ============================================================

-- ── enable RLS ────────────────────────────────────────────────────────────
alter table public.users                    enable row level security;
alter table public.user_xp                  enable row level security;
alter table public.focus_sessions           enable row level security;
alter table public.distraction_events       enable row level security;
alter table public.intervention_events      enable row level security;
alter table public.nightly_analytics_summaries enable row level security;

-- ── users ─────────────────────────────────────────────────────────────────
create policy "users_self_read"   on public.users
  for select using (auth.uid() = id);
create policy "users_self_write"  on public.users
  for insert with check (auth.uid() = id);
create policy "users_self_update" on public.users
  for update using (auth.uid() = id);
create policy "users_self_delete" on public.users
  for delete using (auth.uid() = id);

-- ── user_xp ───────────────────────────────────────────────────────────────
create policy "xp_self_read"   on public.user_xp
  for select using (auth.uid() = user_id);
create policy "xp_self_write"  on public.user_xp
  for insert with check (auth.uid() = user_id);
create policy "xp_self_update" on public.user_xp
  for update using (auth.uid() = user_id);
create policy "xp_self_delete" on public.user_xp
  for delete using (auth.uid() = user_id);

-- ── focus_sessions ────────────────────────────────────────────────────────
create policy "sessions_self_read"   on public.focus_sessions
  for select using (auth.uid() = user_id);
create policy "sessions_self_write"  on public.focus_sessions
  for insert with check (auth.uid() = user_id);
create policy "sessions_self_update" on public.focus_sessions
  for update using (auth.uid() = user_id);
create policy "sessions_self_delete" on public.focus_sessions
  for delete using (auth.uid() = user_id);

-- ── distraction_events ────────────────────────────────────────────────────
-- events are scoped through the parent session's user_id
create policy "events_self_read" on public.distraction_events
  for select using (
    exists (
      select 1 from public.focus_sessions s
      where s.id = session_id and s.user_id = auth.uid()
    )
  );
create policy "events_self_write" on public.distraction_events
  for insert with check (
    exists (
      select 1 from public.focus_sessions s
      where s.id = session_id and s.user_id = auth.uid()
    )
  );
create policy "events_self_update" on public.distraction_events
  for update using (
    exists (
      select 1 from public.focus_sessions s
      where s.id = session_id and s.user_id = auth.uid()
    )
  );
create policy "events_self_delete" on public.distraction_events
  for delete using (
    exists (
      select 1 from public.focus_sessions s
      where s.id = session_id and s.user_id = auth.uid()
    )
  );

-- ── intervention_events ───────────────────────────────────────────────────
create policy "interventions_self_read" on public.intervention_events
  for select using (
    exists (
      select 1 from public.focus_sessions s
      where s.id = session_id and s.user_id = auth.uid()
    )
  );
create policy "interventions_self_write" on public.intervention_events
  for insert with check (
    exists (
      select 1 from public.focus_sessions s
      where s.id = session_id and s.user_id = auth.uid()
    )
  );

-- ── nightly_analytics_summaries ───────────────────────────────────────────
create policy "summaries_self_read" on public.nightly_analytics_summaries
  for select using (auth.uid() = user_id);
create policy "summaries_self_write" on public.nightly_analytics_summaries
  for insert with check (auth.uid() = user_id);
create policy "summaries_self_update" on public.nightly_analytics_summaries
  for update using (auth.uid() = user_id);
