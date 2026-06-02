alter table public.distraction_events
  add column if not exists event_type text not null default 'distraction',
  add column if not exists app_category text,
  add column if not exists time_away_seconds integer,
  add column if not exists risk_score_numeric double precision,
  add column if not exists was_notification_triggered boolean not null default false,
  add column if not exists returned_to_origin boolean not null default false,
  add column if not exists switch_stack_depth integer,
  add column if not exists time_of_day_hour integer,
  add column if not exists day_of_week integer,
  add column if not exists session_minute_when_occurred integer;
