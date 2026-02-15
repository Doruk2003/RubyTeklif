# 15 Dakikalik Release Runbook

Bu runbook, deploy oncesi son kontrol icin hizli ve zorunlu adimlari listeler.

## 1) Kod Kapisi

- `git pull`
- `bin/release_smoke`
- Beklenen: tum adimlar `OK`.

## 2) CI Kapisi

GitHub Actions uzerinde son pipeline'i kontrol et:

- `scan_ruby`
- `scan_js`
- `lint`
- `architecture`
- `test`
- `system-test`
- `release-gate`

Beklenen: tum joblar yesil.

## 3) Supabase Hizli Dogrulama

Supabase SQL Editor'da audit query'lerini calistir:

- `users` ve `activity_logs` icin RLS acik.
- FK / NOT NULL / index audit sonucunda tum satirlar `true`.
- Kritik atomic RPC fonksiyonlari mevcut (create/update/archive/restore).

## 4) Auth / Session Smoke

- Login basarili.
- Refresh token yenileme basarili.
- Refresh fail senaryosunda logout + net uyari mesaji var.

## 5) RBAC Smoke

- Admin disi rol ile admin sayfalarina erisim engelleniyor.
- Son aktif admini demote/disable etme engelleniyor.

## 6) CRUD + Audit Smoke

Moduller:

- Companies
- Products
- Currencies
- Offers

Her modulde create/update/archive/restore akisini kontrol et.
Beklenen: Activity Logs kaydi dusmeli.

## 7) Liste ve Pagination Smoke

Kontrol et:

- Companies
- Products
- Currencies
- Offers
- Admin Users
- Admin Activity Logs

Beklenen: `page/per_page`, filtreler, `Onceki/Sonraki` calisir.

## 8) Job / Queue Smoke

- Export veya reset-password gibi async bir is tetikle.
- Worker/queue akisini kontrol et (Sidekiq + Redis).
- Beklenen: is kuyruga alinir ve tamamlanir.

## 9) Cache Smoke

- Dashboard ve kritik listeleri birkac kez ac.
- Beklenen: veri tutarli, hata yok.

## 10) Performans Ozeti

- `bin/rails observability:performance_report`
- Beklenen: yavas istek orani ve en yavas endpointler listelenir.
- `p95 >= 1000ms` endpoint varsa issue acilir.

## 11) Son Onay

- `git status` temiz.
- Checklistleri isaretle:
  - `docs/release_gate_checklist.md`
  - `docs/release_smoke_checklist.md`

Tum adimlar yesilse deploy yap.
