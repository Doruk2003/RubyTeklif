# Supabase RLS Rollout

Bu proje icin hedef model:

- Uygulama kullanicisi istekleri: `anon key + user JWT`
- Admin/altyapi islemleri: `service_role`
- Tum modullerde sahiplik: `user_id = auth.uid()`

## SQL Uygulama Sirasi

1. `docs/supabase_users_trigger.md` (users tablosu + auth trigger)
2. `docs/activity_logs.sql` (activity_logs tablo tanimi)
3. `db/supabase/20260213_activity_logs_refactor_for_entities.sql`
4. `db/supabase/20260213_enable_rls_and_policies.sql`
5. `db/supabase/20260213_company_offer_stats_view.sql`

## Rol Modeli

- `admin`: tum moduller + activity_logs goruntuleme
- `sales`: companies/products/offers
- `finance`: currencies
- `hr`: uygulama seviyesinde yetkili olabilir, modullerde policy verilmedi

## Notlar

- `service_role` RLS'i bypass eder; sadece zorunlu teknik/admin islemlerde kullanilmalidir.
- CRUD kontrolu policy tarafinda `user_id` ve rol kontrolu ile birlikte uygulanir.
- `activity_logs` artik `target_type + target_id` ile herhangi bir entity icin kayit tutar.
