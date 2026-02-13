-- Make activity_logs usable for any entity (company/product/currency/user/offer).
alter table public.activity_logs
  add column if not exists target_type text not null default 'unknown';

alter table public.activity_logs
  alter column target_id type text using target_id::text;

-- Old schema assumed target_id is always auth.users.id.
alter table public.activity_logs
  drop constraint if exists activity_logs_target_id_fkey;

alter table public.activity_logs
  alter column metadata set default '{}'::jsonb;

