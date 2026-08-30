-- FocusEcho intelligence foundation.  This migration is additive and safe to
-- apply after the existing Sprint 2 schema.

-- Keep public profile rows aligned with Supabase Auth so focus_sessions can
-- safely reference public.users(id).  No access token or provider metadata is
-- copied into the application schema.
create or replace function public.handle_auth_user_created()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.users (id, email, display_name)
  values (
    new.id,
    coalesce(new.email, new.id::text || '@guest.local'),
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', 'FocusEcho user')
  )
  on conflict (id) do update set
    email = excluded.email,
    display_name = excluded.display_name;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_focus_echo on auth.users;
create trigger on_auth_user_created_focus_echo
  after insert on auth.users
  for each row execute procedure public.handle_auth_user_created();

-- Backfill profiles that predate the trigger.
insert into public.users (id, email, display_name)
select
  id,
  coalesce(email, id::text || '@guest.local'),
  coalesce(raw_user_meta_data ->> 'full_name', raw_user_meta_data ->> 'name', 'FocusEcho user')
from auth.users
on conflict (id) do nothing;

alter table public.focus_sessions
  add column if not exists category text not null default 'other',
  add column if not exists score_breakdown jsonb,
  add column if not exists configuration_snapshot jsonb;

create table if not exists public.user_behavior_profiles (
  user_id uuid primary key references public.users(id) on delete cascade,
  best_focus_start_hour smallint,
  optimal_session_minutes smallint,
  highest_risk_start_hour smallint,
  average_recovery_rate double precision,
  updated_at timestamptz not null default now()
);

create table if not exists public.app_behavior_stats (
  user_id uuid not null references public.users(id) on delete cascade,
  package_name text not null,
  app_label text,
  distraction_count integer not null default 0,
  total_duration_seconds integer not null default 0,
  recovery_rate double precision,
  most_common_hour smallint,
  updated_at timestamptz not null default now(),
  primary key (user_id, package_name)
);

create table if not exists public.risk_predictions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  session_id uuid references public.focus_sessions(id) on delete set null,
  predicted_at timestamptz not null default now(),
  probability double precision not null check (probability between 0 and 1),
  risk_level text not null,
  recommended_action text not null,
  confidence double precision not null check (confidence between 0 and 1),
  reasons jsonb not null default '[]'::jsonb,
  features jsonb not null default '{}'::jsonb
);

create table if not exists public.focus_recommendations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  recommendation_type text not null,
  recommended_minutes smallint,
  confidence double precision check (confidence between 0 and 1),
  reason text not null,
  source_window_start timestamptz,
  source_window_end timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_risk_predictions_user_created
  on public.risk_predictions(user_id, predicted_at desc);
create index if not exists idx_app_behavior_stats_user_count
  on public.app_behavior_stats(user_id, distraction_count desc);

alter table public.user_behavior_profiles enable row level security;
alter table public.app_behavior_stats enable row level security;
alter table public.risk_predictions enable row level security;
alter table public.focus_recommendations enable row level security;

create policy "behavior profile: own row" on public.user_behavior_profiles
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "app stats: own rows" on public.app_behavior_stats
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "predictions: own rows" on public.risk_predictions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "recommendations: own rows" on public.focus_recommendations
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
