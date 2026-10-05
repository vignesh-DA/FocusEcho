-- ============================================================
-- Migration: 001_initial_schema
-- Applied: 2026-10-03
-- Source of truth: mobile_app/lib/local_db/database_helper.dart (v1-v4)
--
-- Creates all three core tables with their final column set.
-- Run this once on a fresh Supabase project.
-- ============================================================

-- ── users ─────────────────────────────────────────────────────────────────
-- Managed by Supabase Auth. This table stores the application-level profile.
-- The id here MUST match auth.users.id so RLS policies join correctly.
create table if not exists public.users (
  id          uuid primary key references auth.users(id) on delete cascade,
  email       text,
  display_name text,
  created_at  timestamptz not null default now()
);

-- ── user_xp ───────────────────────────────────────────────────────────────
create table if not exists public.user_xp (
  user_id     uuid primary key references public.users(id) on delete cascade,
  total_xp    integer not null default 0,
  streak_days integer not null default 0,
  updated_at  timestamptz not null default now()
);

-- ── focus_sessions ────────────────────────────────────────────────────────
create table if not exists public.focus_sessions (
  id                   text primary key,          -- client-generated UUID
  user_id              uuid not null references public.users(id) on delete cascade,
  start_time           timestamptz not null,
  end_time             timestamptz,
  productive_app       text not null,
  intent               text not null default '',  -- v3: Feature 1 — Focus Intent
  total_distractions   integer not null default 0,
  total_xp_earned      integer not null default 0,
  focus_score          real    not null default 0.0,
  status               text    not null default 'active',
  is_synced            integer not null default 0, -- client sync flag (not used server-side)
  created_at           timestamptz not null default now()
);

-- ── distraction_events ────────────────────────────────────────────────────
create table if not exists public.distraction_events (
  id                           text primary key,   -- client-generated UUID
  session_id                   text not null references public.focus_sessions(id) on delete cascade,
  package_name                 text not null,
  app_label                    text not null,
  triggered_at                 timestamptz not null,
  recovered_at                 timestamptz,
  recovery_time_seconds        integer,
  risk_score                   text not null,
  event_type                   text not null default 'distraction',
  app_category                 text,
  time_away_seconds            integer,
  risk_score_numeric           real,
  was_notification_triggered   boolean not null default false,
  returned_to_origin           boolean not null default false,
  switch_stack_depth           integer,
  time_of_day_hour             integer,
  day_of_week                  integer,
  session_minute_when_occurred integer,
  escalation_level             integer not null default 1,  -- v4: Feature 2
  is_recovered                 boolean not null default false,
  is_synced                    integer not null default 0,   -- client sync flag
  created_at                   timestamptz not null default now()
);

-- ── intervention_events ───────────────────────────────────────────────────
create table if not exists public.intervention_events (
  id          text primary key,
  session_id  text not null references public.focus_sessions(id) on delete cascade,
  level       integer not null,
  action_taken text not null,
  timestamp   timestamptz not null,
  is_synced   integer not null default 0,
  created_at  timestamptz not null default now()
);

-- ── nightly_analytics_summaries ───────────────────────────────────────────
create table if not exists public.nightly_analytics_summaries (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.users(id) on delete cascade,
  summary_date date not null,
  data        jsonb,
  created_at  timestamptz not null default now(),
  unique (user_id, summary_date)
);
