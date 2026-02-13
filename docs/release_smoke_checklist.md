# Release Smoke Checklist

Bu liste, son degisikliklerden sonra minimum zorunlu kontrolleri kapsar.

## 1) Oturum ve yetki

- Login basarili.
- Refresh token yenilemesi sonrasi oturum devam ediyor.
- Refresh basarisiz olursa login sayfasina dusuyor ve net uyari gorunuyor.
- Yetkisiz rolde erisilmemesi gereken modullerde engel mesaji gorunuyor.

## 2) Liste ekranlari pagination

- Companies: `page/per_page`, `Onceki/Sonraki` calisiyor.
- Products: `page/per_page`, `Onceki/Sonraki` calisiyor.
- Currencies: `page/per_page`, `Onceki/Sonraki` calisiyor.
- Offers: `page/per_page`, `Onceki/Sonraki` calisiyor.
- Admin Users: `page/per_page`, filtre + pagination birlikte calisiyor.
- Admin Activity Logs: filtre + pagination birlikte calisiyor.

## 3) CRUD ve audit log

- Companies create/update/delete sonrasi activity log dusuyor.
- Products create/update/delete sonrasi activity log dusuyor.
- Currencies create/update/delete sonrasi activity log dusuyor.
- Offers create sonrasi activity log dusuyor.
- Admin panel role degisikligi activity log dusuyor.

## 4) Validation ve kullanici mesaji

- Companies formunda zorunlu alanlar bosken net hata mesaji.
- Products formunda gecersiz fiyat/KDV icin net hata mesaji.
- Currencies formunda gecersiz kur icin net hata mesaji.
- Offers formunda kalem yoksa net hata mesaji.

## 5) Supabase dogrulama

- `company_offer_stats` view aktif.
- `users` ve `activity_logs` icin RLS aktif.
- Policy listesi beklenen tablo/rollerle uyumlu.

## 6) Komutlar

- `bin/rubocop`
- `bin/rails test`

