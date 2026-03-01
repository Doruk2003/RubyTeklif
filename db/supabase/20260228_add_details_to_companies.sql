-- Add description, city and country fields to companies table
alter table public.companies
add column description text,
add column city varchar(100),
add column country varchar(100);

-- Drop the view first to avoid column mismatch errors
drop view if exists public.company_with_offer_counts;

-- Recreate the view with the new columns
create view public.company_with_offer_counts
with (security_invoker = true) as
select
  c.id,
  c.name,
  c.tax_number,
  c.tax_office,
  c.authorized_person,
  c.phone,
  c.email,
  c.address,
  c.description,
  c.city,
  c.country,
  c.active,
  c.deleted_at,
  c.created_at,
  coalesce(stats.offers_count, 0)::bigint as offers_count
from public.companies c
left join public.company_offer_stats stats on stats.company_id = c.id;
