create table if not exists public.calendar_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  event_date date not null,
  title text not null,
  description text,
  color text not null default '#38bdf8',
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint calendar_events_title_presence check (char_length(btrim(title)) > 0),
  constraint calendar_events_title_length check (char_length(title) <= 160),
  constraint calendar_events_description_length check (description is null or char_length(description) <= 1000),
  constraint calendar_events_color_hex check (color ~ '^#[0-9A-Fa-f]{6}$')
);

create index if not exists calendar_events_user_deleted_date_idx
  on public.calendar_events(user_id, deleted_at, event_date asc, created_at asc);

alter table public.calendar_events enable row level security;

drop policy if exists calendar_events_owner_read on public.calendar_events;
create policy calendar_events_owner_read
on public.calendar_events for select
using (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'operator', 'viewer', 'sales', 'finance', 'hr'])
);

drop policy if exists calendar_events_owner_insert on public.calendar_events;
create policy calendar_events_owner_insert
on public.calendar_events for insert
with check (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'operator', 'sales'])
);

drop policy if exists calendar_events_owner_update on public.calendar_events;
create policy calendar_events_owner_update
on public.calendar_events for update
using (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'operator', 'sales'])
)
with check (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'operator', 'sales'])
);

drop policy if exists calendar_events_owner_delete on public.calendar_events;
create policy calendar_events_owner_delete
on public.calendar_events for delete
using (
  user_id = auth.uid()
  and public.has_any_role(array['admin', 'manager', 'operator', 'sales'])
);
