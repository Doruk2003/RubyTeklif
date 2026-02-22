-- Performance index pack for high-volume workloads.
-- Strategy: keep Supabase PostgREST/RPC architecture and push scale work into PostgreSQL.

create extension if not exists pg_trgm;

-- Core list sorting / pagination paths (RLS user scoped + soft delete + default sort).
create index if not exists companies_user_deleted_created_idx
  on public.companies (user_id, deleted_at, created_at desc);

create index if not exists products_user_deleted_created_idx
  on public.products (user_id, deleted_at, created_at desc);

create index if not exists offers_user_deleted_offer_date_idx
  on public.offers (user_id, deleted_at, offer_date desc, created_at desc);

create index if not exists categories_user_deleted_name_idx
  on public.categories (user_id, deleted_at, name);

create index if not exists currencies_user_deleted_code_idx
  on public.currencies (user_id, deleted_at, code);

-- Frequently filtered activity log fields.
create index if not exists activity_logs_action_created_idx
  on public.activity_logs (action, created_at desc);

create index if not exists activity_logs_target_type_created_idx
  on public.activity_logs (target_type, created_at desc);

create index if not exists activity_logs_target_id_created_idx
  on public.activity_logs (target_id, created_at desc);

create index if not exists activity_logs_created_idx
  on public.activity_logs (created_at desc);

-- Trigram indexes for ilike-heavy search fields.
create index if not exists companies_name_trgm_idx
  on public.companies using gin (name gin_trgm_ops)
  where deleted_at is null;

create index if not exists companies_authorized_person_trgm_idx
  on public.companies using gin (authorized_person gin_trgm_ops)
  where deleted_at is null;

create index if not exists companies_email_trgm_idx
  on public.companies using gin (email gin_trgm_ops)
  where deleted_at is null;

create index if not exists companies_phone_trgm_idx
  on public.companies using gin (phone gin_trgm_ops)
  where deleted_at is null;

create index if not exists companies_tax_number_trgm_idx
  on public.companies using gin (tax_number gin_trgm_ops)
  where deleted_at is null;

create index if not exists categories_name_trgm_idx
  on public.categories using gin (name gin_trgm_ops)
  where deleted_at is null;

create index if not exists categories_code_trgm_idx
  on public.categories using gin (code gin_trgm_ops)
  where deleted_at is null;

create index if not exists products_name_trgm_idx
  on public.products using gin (name gin_trgm_ops)
  where deleted_at is null;

create index if not exists products_sku_trgm_idx
  on public.products using gin (sku gin_trgm_ops)
  where deleted_at is null;

create index if not exists products_barcode_trgm_idx
  on public.products using gin (barcode gin_trgm_ops)
  where deleted_at is null;
