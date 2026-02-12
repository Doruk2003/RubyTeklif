-- Make tax number uniqueness scoped per user instead of global.
drop index if exists public.companies_tax_number_idx;

create unique index if not exists companies_user_tax_number_idx
  on public.companies(user_id, tax_number);
