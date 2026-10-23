-- FocusEcho database/auth hardening.
-- Apply after the existing schema migrations.
-- Supabase Dashboard: enable Anonymous Auth under Authentication > Providers.

-- Keep application profiles and XP rows in lockstep with every Auth user,
-- including anonymous users.
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

  insert into public.user_xp (user_id, total_xp, streak_days, updated_at)
  values (new.id, 0, 0, now())
  on conflict (user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created_focus_echo on auth.users;
create trigger on_auth_user_created_focus_echo
  after insert on auth.users
  for each row execute procedure public.handle_auth_user_created();

create or replace function public.handle_auth_user_updated()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  update public.users
  set email = coalesce(new.email, new.id::text || '@guest.local'),
      display_name = coalesce(
        new.raw_user_meta_data ->> 'full_name',
        new.raw_user_meta_data ->> 'name',
        display_name
      )
  where id = new.id;
  return new;
end;
$$;

drop trigger if exists on_auth_user_updated_focus_echo on auth.users;
create trigger on_auth_user_updated_focus_echo
  after update of email, raw_user_meta_data on auth.users
  for each row execute procedure public.handle_auth_user_updated();

-- Backfill rows for Auth users created before this migration.
insert into public.users (id, email, display_name)
select id,
       coalesce(email, id::text || '@guest.local'),
       coalesce(raw_user_meta_data ->> 'full_name', raw_user_meta_data ->> 'name', 'FocusEcho user')
from auth.users
on conflict (id) do nothing;

insert into public.user_xp (user_id, total_xp, streak_days, updated_at)
select id, 0, 0, now()
from auth.users
on conflict (user_id) do nothing;

alter table public.users enable row level security;
alter table public.user_xp enable row level security;
alter table public.focus_sessions enable row level security;
alter table public.distraction_events enable row level security;
alter table public.intervention_events enable row level security;

-- Remove policy-name drift from earlier migrations before installing the
-- canonical auth.uid()-based policy set.
do $$
declare
  policy_row record;
begin
  for policy_row in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename in ('users', 'user_xp', 'focus_sessions', 'distraction_events', 'intervention_events')
  loop
    execute format('drop policy if exists %I on %I.%I', policy_row.policyname, policy_row.schemaname, policy_row.tablename);
  end loop;
end;
$$;

create policy focusecho_users_select on public.users
  for select using (auth.uid() = id);
create policy focusecho_users_insert on public.users
  for insert with check (auth.uid() = id);
create policy focusecho_users_update on public.users
  for update using (auth.uid() = id) with check (auth.uid() = id);
create policy focusecho_users_delete on public.users
  for delete using (auth.uid() = id);

create policy focusecho_xp_select on public.user_xp
  for select using (auth.uid() = user_id);
create policy focusecho_xp_insert on public.user_xp
  for insert with check (auth.uid() = user_id);
create policy focusecho_xp_update on public.user_xp
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy focusecho_xp_delete on public.user_xp
  for delete using (auth.uid() = user_id);

create policy focusecho_sessions_select on public.focus_sessions
  for select using (auth.uid() = user_id);
create policy focusecho_sessions_insert on public.focus_sessions
  for insert with check (auth.uid() = user_id);
create policy focusecho_sessions_update on public.focus_sessions
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy focusecho_sessions_delete on public.focus_sessions
  for delete using (auth.uid() = user_id);

create policy focusecho_events_select on public.distraction_events
  for select using (exists (
    select 1 from public.focus_sessions s
    where s.id = session_id and s.user_id = auth.uid()
  ));
create policy focusecho_events_insert on public.distraction_events
  for insert with check (exists (
    select 1 from public.focus_sessions s
    where s.id = session_id and s.user_id = auth.uid()
  ));
create policy focusecho_events_update on public.distraction_events
  for update using (exists (
    select 1 from public.focus_sessions s
    where s.id = session_id and s.user_id = auth.uid()
  )) with check (exists (
    select 1 from public.focus_sessions s
    where s.id = session_id and s.user_id = auth.uid()
  ));
create policy focusecho_events_delete on public.distraction_events
  for delete using (exists (
    select 1 from public.focus_sessions s
    where s.id = session_id and s.user_id = auth.uid()
  ));

create policy focusecho_interventions_select on public.intervention_events
  for select using (exists (
    select 1 from public.focus_sessions s
    where s.id = session_id and s.user_id = auth.uid()
  ));
create policy focusecho_interventions_insert on public.intervention_events
  for insert with check (exists (
    select 1 from public.focus_sessions s
    where s.id = session_id and s.user_id = auth.uid()
  ));
create policy focusecho_interventions_update on public.intervention_events
  for update using (exists (
    select 1 from public.focus_sessions s
    where s.id = session_id and s.user_id = auth.uid()
  )) with check (exists (
    select 1 from public.focus_sessions s
    where s.id = session_id and s.user_id = auth.uid()
  ));
create policy focusecho_interventions_delete on public.intervention_events
  for delete using (exists (
    select 1 from public.focus_sessions s
    where s.id = session_id and s.user_id = auth.uid()
  ));

-- Realtime feeds the mobile/web dashboard and XP view models.
do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'focus_sessions',
    'distraction_events',
    'intervention_events',
    'user_xp'
  ]
  loop
    begin
      execute format(
        'alter publication supabase_realtime add table public.%I',
        table_name
      );
    exception
      when duplicate_object then null;
    end;
  end loop;
end;
$$;