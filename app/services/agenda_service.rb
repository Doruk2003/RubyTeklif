require "date"

class AgendaService
  CACHE_TTL = 2.minutes
  SIDE_LIMIT = 5

  def initialize(client:, actor_id:, cache_store: Rails.cache, repository: nil)
    @actor_id = actor_id.to_s.presence || "anonymous"
    @cache_store = cache_store
    @repository = repository || CalendarEvents::Repository.new(client: client)
  end

  def calendar_events
    records.filter_map do |row|
      next unless row.is_a?(Hash)

      start_at = parsed_time(row["start_at"]) || parsed_date(row["event_date"])&.in_time_zone
      next unless start_at

      {
        id: row["id"].to_s,
        title: row["title"].to_s,
        start: start_at.strftime("%Y-%m-%dT%H:%M:%S"),
        color: normalize_color(row["color"]),
        remindMinutesBefore: row["remind_minutes_before"].to_i,
        description: row["description"].to_s
      }
    end
  end

  def side_items
    rows = records.filter_map do |row|
      next unless row.is_a?(Hash)

      start_at = parsed_time(row["start_at"]) || parsed_date(row["event_date"])&.in_time_zone
      next unless start_at

      serialize_side_item(row, start_at.to_date, start_at)
    end

    upcoming = rows.select { |row| row[:date] >= Date.current }.sort_by { |row| row[:date] }
    picked = upcoming.first(SIDE_LIMIT)
    return picked if picked.any?

    rows.sort_by { |row| row[:date] }.reverse.first(SIDE_LIMIT)
  end

  private

  def records
    cached("events") do
      data = @repository.list_active(user_id: @actor_id, limit: 300)
      unless data.is_a?(Array)
        raise ServiceErrors::System.new(user_message: "Ajanda verileri gecici olarak yuklenemedi. Lutfen tekrar deneyin.")
      end

      data
    end
  end

  def serialize_side_item(row, date, start_at)
    color = normalize_color(row["color"])
    {
      id: row["id"].to_s,
      date: date,
      start_at_value: start_at.strftime("%Y-%m-%dT%H:%M:%S"),
      event_date_value: date.iso8601,
      event_time_value: start_at.strftime("%H:%M"),
      remind_minutes_before: row["remind_minutes_before"].to_i,
      description_value: row["description"].to_s,
      color_value: color,
      day: date.day.to_s.rjust(2, "0"),
      month: I18n.l(date, format: "%b"),
      year: date.year.to_s,
      title: row["title"].to_s,
      text: row["description"].to_s.strip.presence || "Aciklama girilmedi.",
      meta: "Tarih: #{I18n.l(date)} Saat: #{start_at.strftime('%H:%M')}",
      theme_class: theme_class_for(color)
    }
  end

  def parsed_date(value)
    return value if value.is_a?(Date)
    return nil if value.blank?

    Date.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end

  def parsed_time(value)
    return value.in_time_zone if value.respond_to?(:in_time_zone)
    return nil if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def normalize_color(value)
    color = value.to_s.strip
    return "#38bdf8" unless color.match?(/\A#[0-9A-Fa-f]{6}\z/)

    color
  end

  def theme_class_for(color)
    case color.downcase
    when "#84cc16", "#22c55e", "#10b981" then "is-green"
    when "#ef4444", "#f87171", "#dc2626" then "is-red"
    when "#38bdf8", "#0ea5e9", "#3b82f6" then "is-blue"
    else ""
    end
  end

  def cached(section, &block)
    @cache_store.fetch("agenda/#{@actor_id}/#{section}", expires_in: CACHE_TTL, &block)
  end
end
