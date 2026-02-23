require "test_helper"

class AgendaServiceTest < ActiveSupport::TestCase
  class FakeRepository
    def initialize(rows)
      @rows = rows
    end

    def list_active(user_id:, limit:)
      return @rows.first(limit) if @rows.is_a?(Array)

      @rows
    end
  end

  test "calendar_events maps rows into fullcalendar payload" do
    rows = [
      { "event_date" => "2026-03-09", "title" => "Toplanti", "color" => "#22c55e" }
    ]
    service = AgendaService.new(
      client: nil,
      actor_id: "u-1",
      cache_store: ActiveSupport::Cache::MemoryStore.new,
      repository: FakeRepository.new(rows)
    )

    events = service.calendar_events

    assert_equal 1, events.size
    assert_equal "Toplanti", events.first[:title]
    assert_equal "2026-03-09", events.first[:start]
    assert_equal "#22c55e", events.first[:color]
  end

  test "side_items prefer upcoming entries and cap at five" do
    today = Date.current
    rows = 7.times.map do |i|
      {
        "event_date" => (today + i).iso8601,
        "title" => "Etkinlik #{i}",
        "description" => "Aciklama #{i}",
        "color" => "#38bdf8"
      }
    end
    service = AgendaService.new(
      client: nil,
      actor_id: "u-1",
      cache_store: ActiveSupport::Cache::MemoryStore.new,
      repository: FakeRepository.new(rows)
    )

    items = service.side_items

    assert_equal 5, items.size
    assert_equal today.day.to_s.rjust(2, "0"), items.first[:day]
    assert_equal "is-blue", items.first[:theme_class]
  end

  test "raises system error when repository payload is malformed" do
    service = AgendaService.new(
      client: nil,
      actor_id: "u-1",
      cache_store: ActiveSupport::Cache::MemoryStore.new,
      repository: FakeRepository.new({ "error" => "bad" })
    )

    assert_raises(ServiceErrors::System) do
      service.calendar_events
    end
  end
end
