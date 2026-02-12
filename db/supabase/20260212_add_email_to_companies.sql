-- Add company mail address field.
alter table public.companies
  add column if not exists email text;
