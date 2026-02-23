alter table if exists public.calendar_events
  add column if not exists start_at timestamptz,
  add column if not exists remind_minutes_before integer not null default 0;

update public.calendar_events
set start_at = coalesce(start_at, event_date::timestamptz)
where start_at is null;

alter table if exists public.calendar_events
  alter column start_at set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'calendar_events_remind_minutes_before_range'
  ) then
    alter table public.calendar_events
      add constraint calendar_events_remind_minutes_before_range
      check (remind_minutes_before between 0 and 1440);
  end if;
end $$;

create index if not exists calendar_events_user_deleted_start_at_idx
  on public.calendar_events(user_id, deleted_at, start_at asc, created_at asc);
