require "date"
require "uri"

class DashboardService
  CACHE_TTL = 2.minutes
  REMINDER_LIMIT = 5

  def initialize(client:, actor_id: nil, cache_store: Rails.cache)
    @client = client
    @actor_id = actor_id.to_s.presence || "anonymous"
    @cache_store = cache_store
    @calendar_events_repository = CalendarEvents::Repository.new(client: client)
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
      data = @client.get("offers?select=offer_number,offer_date,gross_total,status,companies(name)&deleted_at=is.null&order=offer_date.desc&limit=5")
      unless data.is_a?(Array)
        raise ServiceErrors::System.new(user_message: "Panel teklif verileri gecici olarak yuklenemedi. Lutfen tekrar deneyin.")
      end

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
    cached("reminders") do
      rows = @calendar_events_repository.list_active(user_id: @actor_id, limit: 300)
      unless rows.is_a?(Array)
        raise ServiceErrors::System.new(user_message: "Hatirlatma verileri gecici olarak yuklenemedi. Lutfen tekrar deneyin.")
      end

      items = rows.filter_map do |row|
        next unless row.is_a?(Hash)

        start_at = parse_time(row["start_at"]) || parse_date(row["event_date"])&.in_time_zone
        title = row["title"].to_s.strip
        next if start_at.nil? || title.blank?

        { date: start_at.to_date, time: start_at.strftime("%H:%M"), title: title }
      end

      upcoming = items.select { |item| item[:date] >= Date.current }.sort_by { |item| item[:date] }
      picked = upcoming.first(REMINDER_LIMIT)
      picked = items.sort_by { |item| item[:date] }.reverse.first(REMINDER_LIMIT) if picked.blank?

      picked.map { |item| "#{I18n.l(item[:date])} #{item[:time]} - #{item[:title]}" }
    end
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
    body, response = @client.get_with_response("companies?select=id&deleted_at=is.null&limit=1", headers: { "Prefer" => "count=exact" })
    count_from_response(body, response)
  end

  def count_offers(status: nil)
    path = "offers?select=id&deleted_at=is.null&limit=1"
    path += "&status=eq.#{URI.encode_www_form_component(status)}" if status
    body, response = @client.get_with_response(path, headers: { "Prefer" => "count=exact" })
    count_from_response(body, response)
  end

  def sum_gross_total_this_month
    start = Date.today.beginning_of_month.iso8601
    data = @client.get("offers?select=sum(gross_total)&deleted_at=is.null&offer_date=gte.#{start}")
    unless data.is_a?(Array)
      raise ServiceErrors::System.new(user_message: "Panel ciro verisi gecici olarak yuklenemedi. Lutfen tekrar deneyin.")
    end

    data.first&.fetch("sum", 0) || 0
  end

  def companies_created_since(days:)
    since = (Date.today - days).iso8601
    data = @client.get("companies?select=id&deleted_at=is.null&created_at=gte.#{since}")
    unless data.is_a?(Array)
      raise ServiceErrors::System.new(user_message: "Panel musteri akis verisi gecici olarak yuklenemedi. Lutfen tekrar deneyin.")
    end

    data.size
  end

  def offers_created_since(days:)
    since = (Date.today - days).iso8601
    data = @client.get("offers?select=id&deleted_at=is.null&created_at=gte.#{since}")
    unless data.is_a?(Array)
      raise ServiceErrors::System.new(user_message: "Panel teklif akis verisi gecici olarak yuklenemedi. Lutfen tekrar deneyin.")
    end

    data.size
  end

  def offers_closed_since(days:)
    since = (Date.today - days).iso8601
    data = @client.get("offers?select=id&deleted_at=is.null&created_at=gte.#{since}&status=eq.onaylandi")
    unless data.is_a?(Array)
      raise ServiceErrors::System.new(user_message: "Panel kapanan teklif verisi gecici olarak yuklenemedi. Lutfen tekrar deneyin.")
    end

    data.size
  end

  def count_from_response(body, response)
    content_range = response&.[]( "content-range" )
    if content_range && content_range.include?("/")
      total = content_range.split("/").last
      return total.to_i if total
    end

    return body.size if body.is_a?(Array)

    raise ServiceErrors::System.new(user_message: "Panel sayim verileri gecici olarak yuklenemedi. Lutfen tekrar deneyin.")
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

  def parse_date(value)
    return value if value.is_a?(Date)
    return nil if value.blank?

    Date.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end

  def parse_time(value)
    return value.in_time_zone if value.respond_to?(:in_time_zone)
    return nil if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError
    nil
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
