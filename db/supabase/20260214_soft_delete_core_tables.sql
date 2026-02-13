alter table public.companies add column if not exists deleted_at timestamptz;
alter table public.categories add column if not exists deleted_at timestamptz;
alter table public.products add column if not exists deleted_at timestamptz;
alter table public.currencies add column if not exists deleted_at timestamptz;
alter table public.offers add column if not exists deleted_at timestamptz;
alter table public.offer_items add column if not exists deleted_at timestamptz;

create index if not exists companies_deleted_at_idx on public.companies(deleted_at);
create index if not exists categories_deleted_at_idx on public.categories(deleted_at);
create index if not exists products_deleted_at_idx on public.products(deleted_at);
create index if not exists currencies_deleted_at_idx on public.currencies(deleted_at);
create index if not exists offers_deleted_at_idx on public.offers(deleted_at);
create index if not exists offer_items_deleted_at_idx on public.offer_items(deleted_at);

drop index if exists public.companies_user_tax_number_idx;
create unique index if not exists companies_user_tax_number_idx
  on public.companies(user_id, tax_number)
  where deleted_at is null and tax_number is not null;

drop index if exists public.categories_user_code_key;
create unique index if not exists categories_user_code_key
  on public.categories(user_id, code)
  where deleted_at is null;

drop index if exists public.categories_user_name_key;
create unique index if not exists categories_user_name_key
  on public.categories(user_id, name)
  where deleted_at is null;
