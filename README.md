# RubyTeklif

Rails + Supabase tabanli teklif/CRM uygulamasi.

## Temel Ozellikler

- Rol bazli erisim: `admin`, `manager`, `operator`, `viewer`
- Supabase RLS policy yapisi
- Atomic RPC tabanli CRUD + audit log
- Soft delete (`deleted_at`) + restore akislari
- Admin panel: kullanici yonetimi, activity logs, CSV export

## Kurulum

1. Ruby surumunu `.ruby-version` ile uyumlu kur.
2. Bagimliliklari yukle:
   - `bundle install`
3. Ortam degiskenlerini tanimla:
   - `.env.example` dosyasini `.env` olarak kopyala ve degerleri doldur.
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `SUPABASE_SERVICE_USER_ID`
4. Uygulamayi baslat:
   - `bin/dev`
5. Job adapter secimi:
   - Development varsayilan: `ACTIVE_JOB_QUEUE_ADAPTER=async`
   - Test varsayilan: `:test`
   - Production varsayilan: `ACTIVE_JOB_QUEUE_ADAPTER=sidekiq`
   - Sidekiq icin `REDIS_URL` tanimli olmalidir.
6. Sidekiq calistirma (development/production):
   - `bundle exec sidekiq -C config/sidekiq.yml`
7. Cache adapter secimi:
   - Production varsayilan: `CACHE_STORE_ADAPTER=solid_cache_store`
   - Redis cache icin: `CACHE_STORE_ADAPTER=redis_cache_store` ve `REDIS_URL` tanimli olmalidir.

## Test ve Kalite Kapisi

- Tum testler: `bin/rails test`
- Mimari sinir testleri: `bin/rails test test/architecture`
- Koku analizi: `bin/reek app`
- Stil: `bin/rubocop`
- Guvenlik: `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`

CI pipeline su ana joblari icerir:

- `scan_ruby` (brakeman + bundler-audit)
- `scan_js` (importmap audit)
- `lint` (rubocop + reek)
- `architecture` (boundary testleri)
- `test`
- `system-test`
- `release-gate` (tum kapilarin ozet yesil durumu)

## Environment Ayrimi

- `development`: lokal gelistirme
- `test`: otomatik testler
- `staging`: canli oncesi dogrulama (`RAILS_ENV=staging`)
- `production`: canli trafik

## Supabase SQL

SQL migration dosyalari `db/supabase` altindadir.
Bu projede SQL dosyalari Supabase SQL Editor uzerinden manuel calistirilabilir.

## Release

Canliya cikis oncesi zorunlu checklist:

- `docs/release_smoke_checklist.md`
- `docs/release_gate_checklist.md`
