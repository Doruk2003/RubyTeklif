-- Aggregated offer counts per company for faster companies list queries.
create or replace view public.company_offer_stats
with (security_invoker = true) as
select
  o.company_id,
  count(*)::bigint as offers_count
from public.offers o
group by o.company_id;

