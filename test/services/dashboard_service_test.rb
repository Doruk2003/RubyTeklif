require "test_helper"

class DashboardServiceTest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :get_calls, :get_with_response_calls

    def initialize
      @get_calls = []
      @get_with_response_calls = []
    end

    def get(path)
      @get_calls << path
      return [{ "sum" => 1250.5 }] if path.start_with?("offers?select=sum(gross_total)")
      return [{ "offer_number" => "T-1", "gross_total" => 100, "status" => "beklemede", "companies" => { "name" => "ACME" } }] if path.start_with?("offers?select=offer_number")
      return [{ "id" => "1" }] if path.include?("created_at=gte.")

      []
    end

    def get_with_response(path, headers:)
      @get_with_response_calls << [path, headers]
      [[], { "content-range" => "0-0/1" }]
    end
  end

  test "kpis are cached per actor" do
    client = FakeClient.new
    cache = ActiveSupport::Cache::MemoryStore.new
    service = DashboardService.new(client: client, actor_id: "usr-1", cache_store: cache)

    first = service.kpis
    second = service.kpis

    assert_equal first, second
    assert_equal 2, client.get_with_response_calls.size
    assert_equal 1, client.get_calls.count { |p| p.start_with?("offers?select=sum(gross_total)") }
  end

  test "recent_offers are cached per actor" do
    client = FakeClient.new
    cache = ActiveSupport::Cache::MemoryStore.new
    service = DashboardService.new(client: client, actor_id: "usr-1", cache_store: cache)

    first = service.recent_offers
    second = service.recent_offers

    assert_equal first, second
    assert_equal 1, client.get_calls.count { |p| p.start_with?("offers?select=offer_number") }
  end
end
