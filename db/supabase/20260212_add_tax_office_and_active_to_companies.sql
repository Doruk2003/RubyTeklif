-- Add company tax office and active/passive tracking fields.
alter table public.companies
  add column if not exists tax_office text,
  add column if not exists active boolean not null default true;

create index if not exists companies_active_idx
  on public.companies(active);
