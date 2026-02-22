# Release Gate Checklist

Bu liste merge/deploy oncesi "go/no-go" kararini standartlastirir.

## 1) Kod ve Mimari Kapilari

- [ ] `bin/rails test` basarili.
- [ ] `bin/rails test test/architecture` basarili.
- [ ] `bin/rails quality:guard` basarili.
- [ ] `bin/reek app` basarili.
- [ ] `bin/rubocop` basarili.
- [ ] Controller katmaninda dogrudan Supabase CRUD cagrisi yok.
- [ ] Repository mutasyonlari atomic RPC disina cikmiyor.
- [ ] Mutasyon RPC payloadlarinda `p_actor_id` var.

## 2) Guvenlik ve Yetki

- [ ] `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` basarili.
- [ ] Admin/Manager/Operator/Viewer policy matrix testleri gecerli.
- [ ] Son aktif admini dusurme/devre disi birakma engeli testli.
- [ ] Session timeout ve refresh fail-back senaryolari testli.

## 3) Supabase Butunlugu

- [ ] Iliskilerde FK + `NOT NULL` + index kontrolleri dogrulandi.
- [ ] `users` ve `activity_logs` RLS aktif.
- [ ] CRUD yapan core endpointler atomic RPC uzerinden calisiyor.
- [ ] Soft-delete filtreleri aktif listelerde uygulanmis.

## 4) Gozlemlenebilirlik

- [ ] `Observability::ErrorReporter` testleri gecerli.
- [ ] Validation/Policy hatalari Sentry'ye gitmiyor.
- [ ] Runtime hatalarinda Sentry context/tag set ediliyor.
- [ ] Yavas istek alarmi aktif (`http.request.slow` eventleri uretiliyor).
- [ ] `bin/rails observability:performance_report` cikisi gozden gecirildi.

## 5) Operasyonel Kontrol

- [ ] CI'da tum joblar yesil (scan/lint/architecture/test/system-test).
- [ ] CI `release-gate` job'u yesil.
- [ ] Son commitler `main` ile senkron.
- [ ] Uretim ortam degiskenleri guncel ve eksiksiz.
- [ ] Smoke testler (`docs/release_smoke_checklist.md`) tamamlandi.
