-- Companies with non-deleted offer counts for DB-side sorting/filtering/pagination.
create or replace view public.company_with_offer_counts
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
  c.active,
  c.deleted_at,
  c.created_at,
  coalesce(stats.offers_count, 0)::bigint as offers_count
from public.companies c
left join public.company_offer_stats stats on stats.company_id = c.id;
