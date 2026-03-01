-- Dropping previous views to update with new columns
drop view if exists public.company_with_offer_counts;
drop view if exists public.company_offer_stats;

-- Create enhanced company_offer_stats view
create or replace view public.company_offer_stats
with (security_invoker = true) as
select
  o.company_id,
  count(*)::bigint as total_offers_count,
  sum(case when o.deleted_at is null then 1 else 0 end)::bigint as active_offers_count,
  sum(case when o.status = 'approved' and o.deleted_at is null then 1 else 0 end)::bigint as approved_offers_count,
  coalesce(sum(case when o.deleted_at is null then o.gross_total else 0 end), 0)::numeric as total_offer_amount,
  coalesce(sum(case when o.status = 'approved' and o.deleted_at is null then o.gross_total else 0 end), 0)::numeric as approved_offer_amount
from public.offers o
group by o.company_id;

-- Create enhanced company_with_offer_counts view
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
  c.description,
  c.city,
  c.country,
  c.active,
  c.deleted_at,
  c.created_at,
  coalesce(stats.active_offers_count, 0)::bigint as offers_count,
  coalesce(stats.total_offers_count, 0)::bigint as total_offers_count,
  coalesce(stats.approved_offers_count, 0)::bigint as approved_offers_count,
  coalesce(stats.total_offer_amount, 0)::numeric as total_offer_amount,
  coalesce(stats.approved_offer_amount, 0)::numeric as approved_offer_amount
from public.companies c
left join public.company_offer_stats stats on stats.company_id = c.id;
