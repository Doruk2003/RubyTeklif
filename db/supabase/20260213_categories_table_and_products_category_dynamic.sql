create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  code text not null,
  name text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists categories_user_code_key on public.categories(user_id, code);
create unique index if not exists categories_user_name_key on public.categories(user_id, name);
create index if not exists categories_user_active_idx on public.categories(user_id, active);

insert into public.categories(user_id, code, name, active)
select distinct
  p.user_id,
  lower(trim(p.category)),
  initcap(replace(lower(trim(p.category)), '_', ' ')),
  true
from public.products p
where p.user_id is not null
  and p.category is not null
  and btrim(p.category) <> ''
on conflict do nothing;

alter table public.products
  drop constraint if exists products_category_check;

alter table public.categories enable row level security;

drop policy if exists categories_owner_read on public.categories;
create policy categories_owner_read
on public.categories for select
using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.role in ('admin', 'sales')
  )
);

drop policy if exists categories_owner_insert on public.categories;
create policy categories_owner_insert
on public.categories for insert
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.role in ('admin', 'sales')
  )
);

drop policy if exists categories_owner_update on public.categories;
create policy categories_owner_update
on public.categories for update
using (
  user_id = auth.uid()
  and exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.role in ('admin', 'sales')
  )
)
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.role in ('admin', 'sales')
  )
);

drop policy if exists categories_owner_delete on public.categories;
create policy categories_owner_delete
on public.categories for delete
using (
  user_id = auth.uid()
  and exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.role in ('admin', 'sales')
  )
);
