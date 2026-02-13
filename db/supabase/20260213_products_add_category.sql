alter table public.products
  add column if not exists category text;

update public.products
set category = 'general'
where category is null or btrim(category) = '';

alter table public.products
  alter column category set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'products_category_check'
  ) then
    alter table public.products
      add constraint products_category_check
      check (category in ('general', 'raw_material', 'finished_goods', 'service', 'spare_part'));
  end if;
end $$;
