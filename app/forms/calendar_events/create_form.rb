require "date"

module CalendarEvents
  class CreateForm
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :event_date, :string
    attribute :event_time, :string
    attribute :title, :string
    attribute :description, :string
    attribute :color, :string
    attribute :remind_minutes_before, :integer, default: 0

    validates :event_date, presence: true
    validates :event_time, presence: true
    validates :title, presence: true, length: { maximum: 160 }
    validates :description, length: { maximum: 1000 }, allow_blank: true
    validates :color, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }, allow_blank: true
    validates :remind_minutes_before, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 1440 }
    validate :event_date_must_be_parseable
    validate :event_time_must_be_parseable

    def normalized_attributes
      {
        event_date: parsed_event_date.iso8601,
        start_at: parsed_start_at.iso8601,
        title: title.to_s.strip,
        description: description.to_s.strip.presence,
        color: normalized_color,
        remind_minutes_before: normalized_remind_minutes_before
      }
    end

    private

    def parsed_event_date
      @parsed_event_date ||= Date.iso8601(event_date.to_s)
    end

    def parsed_start_at
      @parsed_start_at ||= begin
        hour, minute = parsed_time_parts
        Time.zone.local(parsed_event_date.year, parsed_event_date.month, parsed_event_date.day, hour, minute, 0)
      end
    end

    def parsed_time_parts
      raw = event_time.to_s.strip
      raise ArgumentError if raw.blank?

      parts = raw.split(":", 2)
      raise ArgumentError unless parts.size == 2

      hour = Integer(parts[0], 10)
      minute = Integer(parts[1], 10)
      raise ArgumentError unless hour.between?(0, 23) && minute.between?(0, 59)

      [hour, minute]
    end

    def event_date_must_be_parseable
      return if event_date.blank?
      return if parsed_event_date

      errors.add(:event_date, "gecersiz")
    rescue Date::Error
      errors.add(:event_date, "gecersiz")
    end

    def event_time_must_be_parseable
      return if event_time.blank?

      parsed_time_parts
    rescue ArgumentError
      errors.add(:event_time, "gecersiz")
    end

    def normalized_color
      value = color.to_s.strip
      return "#38bdf8" if value.blank?

      value
    end

    def normalized_remind_minutes_before
      value = remind_minutes_before.to_i
      return 0 if value.negative?

      value
    end
  end
end
