# Observability Ops Standard

Bu dokuman, runtime hata yonetimi, yavas endpoint alarmi ve duzenli performans raporunu standartlastirir.

## 1) Hata ve Alarm Standardi

- Tum runtime hatalari `Observability::ErrorReporter` ile raporlanir.
- Validation/Policy tipi beklenen is kurali hatalari Sentry'ye gonderilmez.
- Her HTTP istegi `http.request` eventi ile sure (`duration_ms`) bilgisiyle loglanir.
- `duration_ms >= SLOW_REQUEST_THRESHOLD_MS` oldugunda `http.request.slow` warning logu uretilir.

## 2) Ortam Degiskenleri

- `SENTRY_DSN`: Sentry entegrasyonu icin zorunlu (opsiyonel ortamlarda bos birakilabilir).
- `SLOW_REQUEST_THRESHOLD_MS`: Yavas endpoint alarm esigi (varsayilan: `750`).

## 3) Gunluk Rapor

- Komut:
  - `bin/rails observability:performance_report`
- Opsiyonel:
  - `LOG_PATH=log/production.log`
  - `SLOW_REQUEST_THRESHOLD_MS=900`
- Beklenen cikti:
  - Toplam istek
  - Yavas istek sayisi ve orani
  - Endpoint bazli `count`, `avg`, `p95`, `max`, `slow`, `slow%`

## 4) Operasyonel Aksiyon Esikleri

- `slow_ratio >= 10%`: endpoint bazli inceleme ac.
- `p95 >= 1000ms`: ilgili endpoint icin sorgu/indeks/N+1 analizi yap.
- Son 24 saatte tekrar eden `http.request.slow` eventleri:
  - Issue ac
  - Sorumlu ata
  - Bir sonraki release'te takip et

## 5) Haftalik Rutin

- Haftada en az 1 kez performans raporu uret.
- En yavas 5 endpointi onceki haftayla karsilastir.
- Degisim trendini release notuna ekle.
