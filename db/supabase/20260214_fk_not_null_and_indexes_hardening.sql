-- FK + NOT NULL + index hardening for core relations.
-- Run after cleaning null/orphan data if any exception is raised.

create index if not exists companies_user_id_idx on public.companies(user_id);
create index if not exists categories_user_id_idx on public.categories(user_id);
create index if not exists products_user_id_idx on public.products(user_id);
create index if not exists offers_user_id_idx on public.offers(user_id);
create index if not exists offers_company_id_idx on public.offers(company_id);
create index if not exists offer_items_user_id_idx on public.offer_items(user_id);
create index if not exists offer_items_offer_id_idx on public.offer_items(offer_id);
create index if not exists offer_items_product_id_idx on public.offer_items(product_id);
create index if not exists currencies_user_id_idx on public.currencies(user_id);
create index if not exists activity_logs_actor_id_idx on public.activity_logs(actor_id);

do $$
begin
  if exists (select 1 from public.companies where user_id is null) then
    raise exception 'companies.user_id has null values';
  end if;
  if exists (select 1 from public.categories where user_id is null) then
    raise exception 'categories.user_id has null values';
  end if;
  if exists (select 1 from public.products where user_id is null) then
    raise exception 'products.user_id has null values';
  end if;
  if exists (select 1 from public.offers where user_id is null or company_id is null) then
    raise exception 'offers.user_id/company_id has null values';
  end if;
  if exists (select 1 from public.offer_items where user_id is null or offer_id is null or product_id is null) then
    raise exception 'offer_items foreign key columns have null values';
  end if;
  if exists (select 1 from public.currencies where user_id is null) then
    raise exception 'currencies.user_id has null values';
  end if;
  if exists (select 1 from public.activity_logs where actor_id is null) then
    raise exception 'activity_logs.actor_id has null values';
  end if;
end $$;

alter table public.companies alter column user_id set not null;
alter table public.categories alter column user_id set not null;
alter table public.products alter column user_id set not null;
alter table public.offers alter column user_id set not null;
alter table public.offers alter column company_id set not null;
alter table public.offer_items alter column user_id set not null;
alter table public.offer_items alter column offer_id set not null;
alter table public.offer_items alter column product_id set not null;
alter table public.currencies alter column user_id set not null;
alter table public.activity_logs alter column actor_id set not null;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'companies_user_id_fkey') then
    alter table public.companies
      add constraint companies_user_id_fkey
      foreign key (user_id) references public.users(id)
      on update cascade on delete restrict;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'categories_user_id_fkey') then
    alter table public.categories
      add constraint categories_user_id_fkey
      foreign key (user_id) references public.users(id)
      on update cascade on delete restrict;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'products_user_id_fkey') then
    alter table public.products
      add constraint products_user_id_fkey
      foreign key (user_id) references public.users(id)
      on update cascade on delete restrict;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'offers_user_id_fkey') then
    alter table public.offers
      add constraint offers_user_id_fkey
      foreign key (user_id) references public.users(id)
      on update cascade on delete restrict;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'offers_company_id_fkey') then
    alter table public.offers
      add constraint offers_company_id_fkey
      foreign key (company_id) references public.companies(id)
      on update cascade on delete restrict;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'offer_items_user_id_fkey') then
    alter table public.offer_items
      add constraint offer_items_user_id_fkey
      foreign key (user_id) references public.users(id)
      on update cascade on delete restrict;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'offer_items_offer_id_fkey') then
    alter table public.offer_items
      add constraint offer_items_offer_id_fkey
      foreign key (offer_id) references public.offers(id)
      on update cascade on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'offer_items_product_id_fkey') then
    alter table public.offer_items
      add constraint offer_items_product_id_fkey
      foreign key (product_id) references public.products(id)
      on update cascade on delete restrict;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'currencies_user_id_fkey') then
    alter table public.currencies
      add constraint currencies_user_id_fkey
      foreign key (user_id) references public.users(id)
      on update cascade on delete restrict;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'activity_logs_actor_id_fkey') then
    alter table public.activity_logs
      add constraint activity_logs_actor_id_fkey
      foreign key (actor_id) references public.users(id)
      on update cascade on delete restrict;
  end if;
end $$;
