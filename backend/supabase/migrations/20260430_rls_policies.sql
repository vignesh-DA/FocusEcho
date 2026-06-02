-- ============================================================
-- Focus Echo AI — Row Level Security Policies
-- Run this in Supabase SQL Editor after 20260416_sprint2_schema.sql
-- ============================================================

-- users: each user can only see and update their own row
alter table public.users enable row level security;

create policy "users: select own row"
  on public.users for select
  using (auth.uid() = id);

create policy "users: insert own row"
  on public.users for insert
  with check (auth.uid() = id);

create policy "users: update own row"
  on public.users for update
  using (auth.uid() = id);

create policy "users: delete own row"
  on public.users for delete
  using (auth.uid() = id);

-- user_xp
alter table public.user_xp enable row level security;

create policy "user_xp: select own"
  on public.user_xp for select
  using (auth.uid() = user_id);

create policy "user_xp: upsert own"
  on public.user_xp for insert
  with check (auth.uid() = user_id);

create policy "user_xp: update own"
  on public.user_xp for update
  using (auth.uid() = user_id);

-- focus_sessions
alter table public.focus_sessions enable row level security;

create policy "focus_sessions: select own"
  on public.focus_sessions for select
  using (auth.uid() = user_id);

create policy "focus_sessions: insert own"
  on public.focus_sessions for insert
  with check (auth.uid() = user_id);

create policy "focus_sessions: update own"
  on public.focus_sessions for update
  using (auth.uid() = user_id);

create policy "focus_sessions: delete own"
  on public.focus_sessions for delete
  using (auth.uid() = user_id);

-- distraction_events: access via session ownership
alter table public.distraction_events enable row level security;

create policy "distraction_events: select own"
  on public.distraction_events for select
  using (
    exists (
      select 1 from public.focus_sessions s
      where s.id = session_id and s.user_id = auth.uid()
    )
  );

create policy "distraction_events: insert own"
  on public.distraction_events for insert
  with check (
    exists (
      select 1 from public.focus_sessions s
      where s.id = session_id and s.user_id = auth.uid()
    )
  );

create policy "distraction_events: update own"
  on public.distraction_events for update
  using (
    exists (
      select 1 from public.focus_sessions s
      where s.id = session_id and s.user_id = auth.uid()
    )
  );

-- nightly_analytics_summaries
alter table public.nightly_analytics_summaries enable row level security;

create policy "nightly_summaries: select own"
  on public.nightly_analytics_summaries for select
  using (auth.uid() = user_id);

create policy "nightly_summaries: insert own"
  on public.nightly_analytics_summaries for insert
  with check (auth.uid() = user_id);

create policy "nightly_summaries: update own"
  on public.nightly_analytics_summaries for update
  using (auth.uid() = user_id);
