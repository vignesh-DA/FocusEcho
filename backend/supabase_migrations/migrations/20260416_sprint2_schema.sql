-- Focus Echo AI Sprint 2 schema (Supabase/PostgreSQL)
create extension if not exists pgcrypto;

create table if not exists public.users (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,
  display_name text not null,
  joined_at timestamptz not null default now()
);

create table if not exists public.user_xp (
  user_id uuid primary key references public.users(id) on delete cascade,
  total_xp integer not null default 0,
  streak_days integer not null default 0,
  longest_streak integer not null default 0,
  updated_at timestamptz not null default now()
);

create table if not exists public.focus_sessions (
  id uuid primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  start_time timestamptz not null,
  end_time timestamptz,
  productive_app text not null,
  total_distractions integer not null default 0,
  total_xp_earned integer not null default 0,
  focus_score double precision not null default 0,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.distraction_events (
  id uuid primary key,
  session_id uuid not null references public.focus_sessions(id) on delete cascade,
  package_name text not null,
  app_label text not null,
  triggered_at timestamptz not null,
  recovered_at timestamptz,
  recovery_time_seconds integer,
  risk_score text not null,
  is_recovered boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.nightly_analytics_summaries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  summary_date date not null,
  total_sessions integer not null default 0,
  total_distractions integer not null default 0,
  avg_focus_score double precision not null default 0,
  created_at timestamptz not null default now(),
  unique(user_id, summary_date)
);

create index if not exists idx_focus_sessions_user_start
  on public.focus_sessions(user_id, start_time desc);

create index if not exists idx_distraction_events_session_triggered
  on public.distraction_events(session_id, triggered_at desc);
