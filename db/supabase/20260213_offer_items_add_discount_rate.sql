alter table public.offer_items
  add column if not exists discount_rate numeric(5,2);

update public.offer_items
set discount_rate = 0
where discount_rate is null;

alter table public.offer_items
  alter column discount_rate set default 0;

alter table public.offer_items
  alter column discount_rate set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'offer_items_discount_rate_check'
  ) then
    alter table public.offer_items
      add constraint offer_items_discount_rate_check
      check (discount_rate >= 0 and discount_rate <= 100);
  end if;
end $$;
