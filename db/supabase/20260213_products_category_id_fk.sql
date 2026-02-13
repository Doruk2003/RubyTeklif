alter table public.products
  add column if not exists category_id uuid;

update public.products p
set category_id = c.id
from public.categories c
where p.category_id is null
  and p.user_id = c.user_id
  and lower(trim(p.category)) = c.code;

insert into public.categories (user_id, code, name, active)
select distinct
  p.user_id,
  lower(trim(p.category)) as code,
  initcap(replace(lower(trim(p.category)), '_', ' ')) as name,
  true
from public.products p
where p.category_id is null
  and p.user_id is not null
  and p.category is not null
  and btrim(p.category) <> ''
on conflict (user_id, code) do nothing;

update public.products p
set category_id = c.id
from public.categories c
where p.category_id is null
  and p.user_id = c.user_id
  and lower(trim(p.category)) = c.code;

create index if not exists products_category_id_idx on public.products(category_id);

alter table public.products
  alter column category_id set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'products_category_id_fkey'
  ) then
    alter table public.products
      add constraint products_category_id_fkey
      foreign key (category_id)
      references public.categories(id)
      on update cascade
      on delete restrict;
  end if;
end $$;
