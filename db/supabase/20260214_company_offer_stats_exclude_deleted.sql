create or replace view public.company_offer_stats
with (security_invoker = true) as
select
  o.company_id,
  count(*)::bigint as offers_count
from public.offers o
where o.deleted_at is null
group by o.company_id;
