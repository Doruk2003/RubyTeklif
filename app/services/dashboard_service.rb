require "date"
require "uri"

class DashboardService
  CACHE_TTL = 2.minutes

  def initialize(client:, actor_id: nil, cache_store: Rails.cache)
    @client = client
    @actor_id = actor_id.to_s.presence || "anonymous"
    @cache_store = cache_store
  end

  def kpis
    cached("kpis") do
      [
        active_customers_kpi,
        open_offers_kpi,
        monthly_revenue_kpi
      ]
    end
  end

  def recent_offers
    cached("recent_offers") do
      data = @client.get("offers?select=offer_number,offer_date,gross_total,status,companies(name)&order=offer_date.desc&limit=5")
      return [] unless data.is_a?(Array)

      data.map { |row| serialize_recent_offer_row(row) }
    end
  end

  def flow_stats
    cached("flow_stats") do
      [
        {
          label: "Yeni Müşteri",
          value: companies_created_since(days: 7).to_s,
          note: "Son 7 gün"
        },
        {
          label: "Oluşturulan Teklif",
          value: offers_created_since(days: 7).to_s,
          note: "Son 7 gün"
        },
        {
          label: "Kapanan Teklif",
          value: offers_closed_since(days: 7).to_s,
          note: "Son 7 gün"
        }
      ]
    end
  end

  def reminders
    [
      "Son 48 saatte güncellenmeyen teklifleri kontrol edin.",
      "Onay bekleyen teklifler için müşteri geri dönüşü alın.",
      "Fiyat listesi güncellemesini paylaşmayı unutmayın."
    ]
  end

  private

  def active_customers_kpi
    count = count_companies
    {
      label: "Aktif Müşteri",
      value: count.to_s,
      delta: "Toplam kayıt",
      delta_class: "text-sky-700",
      bar_class: "bg-sky-500",
      bar_width: bar_width(count)
    }
  end

  def open_offers_kpi
    count = count_offers(status: "beklemede")
    {
      label: "Açık Teklifler",
      value: count.to_s,
      delta: "Onay bekliyor",
      delta_class: "text-amber-600",
      bar_class: "bg-amber-500",
      bar_width: bar_width(count)
    }
  end

  def monthly_revenue_kpi
    total = sum_gross_total_this_month
    {
      label: "Aylık Ciro",
      value: format_currency(total),
      delta: "Bu ay",
      delta_class: "text-emerald-700",
      bar_class: "bg-emerald-500",
      bar_width: "w-3/4"
    }
  end

  def count_companies
    body, response = @client.get_with_response("companies?select=id&limit=1", headers: { "Prefer" => "count=exact" })
    count_from_response(body, response)
  end

  def count_offers(status: nil)
    path = "offers?select=id&limit=1"
    path += "&status=eq.#{URI.encode_www_form_component(status)}" if status
    body, response = @client.get_with_response(path, headers: { "Prefer" => "count=exact" })
    count_from_response(body, response)
  end

  def sum_gross_total_this_month
    start = Date.today.beginning_of_month.iso8601
    data = @client.get("offers?select=sum(gross_total)&offer_date=gte.#{start}")
    return 0 unless data.is_a?(Array)

    data.first&.fetch("sum", 0) || 0
  end

  def companies_created_since(days:)
    since = (Date.today - days).iso8601
    data = @client.get("companies?select=id&created_at=gte.#{since}")
    data.is_a?(Array) ? data.size : 0
  end

  def offers_created_since(days:)
    since = (Date.today - days).iso8601
    data = @client.get("offers?select=id&created_at=gte.#{since}")
    data.is_a?(Array) ? data.size : 0
  end

  def offers_closed_since(days:)
    since = (Date.today - days).iso8601
    data = @client.get("offers?select=id&created_at=gte.#{since}&status=eq.onaylandi")
    data.is_a?(Array) ? data.size : 0
  end

  def count_from_response(body, response)
    content_range = response&.[]( "content-range" )
    if content_range && content_range.include?("/")
      total = content_range.split("/").last
      return total.to_i if total
    end

    return body.size if body.is_a?(Array)

    0
  end

  def format_currency(value)
    number = value.to_f
    "₺ #{format('%.2f', number)}"
  end

  def status_badge_class(status)
    case status.downcase
    when "beklemede", "gonderildi"
      "badge-warn"
    when "onaylandi"
      "badge-success"
    when "reddedildi"
      "badge-info"
    else
      "badge-info"
    end
  end

  def bar_width(count)
    case count.to_i
    when 0..5 then "w-1/4"
    when 6..15 then "w-1/2"
    else "w-3/4"
    end
  end

  def cached(section, &block)
    @cache_store.fetch("dashboard/#{@actor_id}/#{section}", expires_in: CACHE_TTL, &block)
  end

  # :reek:FeatureEnvy
  def serialize_recent_offer_row(row)
    status = (row["status"] || "Taslak").to_s
    {
      number: row["offer_number"].to_s,
      company: row.dig("companies", "name").to_s,
      amount: format_currency(row["gross_total"]),
      status: status,
      status_class: status_badge_class(status)
    }
  end
end
