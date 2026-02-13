require "test_helper"

module Companies
  class IndexQueryTest < ActiveSupport::TestCase
    class FakeClient
      attr_reader :paths

      def initialize(companies_response:, offer_stats_response: [], offers_response: [])
        @companies_response = companies_response
        @offer_stats_response = offer_stats_response
        @offers_response = offers_response
        @paths = []
      end

      def get(path)
        @paths << path
        return @offer_stats_response if path.start_with?("company_offer_stats?")
        return @offers_response if path.start_with?("offers?")

        @companies_response
      end
    end

    test "builds DB query with filters sort and pagination" do
      client = FakeClient.new(companies_response: [])
      query = Companies::IndexQuery.new(client: client)

      result = query.call(
        params: {
          q: "acme",
          tax_number: "123",
          active: "1",
          sort: "name",
          dir: "asc",
          page: "2",
          per_page: "25"
        }
      )

      path = client.paths.first
      assert_includes path, "order=name.asc"
      assert_includes path, "limit=26"
      assert_includes path, "offset=25"
      assert_includes path, "tax_number=ilike.*123*"
      assert_includes path, "active=eq.true"
      assert_includes path, "or=(name.ilike.*acme*"
      assert_equal 2, result[:page]
      assert_equal 25, result[:per_page]
      assert_equal true, result[:has_prev]
    end

    test "filters has_offers and sorts by offers_count when requested" do
      companies = [
        { "id" => "cmp-1", "name" => "A", "active" => true },
        { "id" => "cmp-2", "name" => "B", "active" => true }
      ]
      stats = [{ "company_id" => "cmp-2", "offers_count" => 2 }]
      client = FakeClient.new(companies_response: companies, offer_stats_response: stats)
      query = Companies::IndexQuery.new(client: client)

      result = query.call(params: { has_offers: "1", sort: "offers_count", dir: "desc" })

      assert_equal 1, result[:items].size
      assert_equal "cmp-2", result[:items].first.id
      assert_equal 2, result[:items].first.offers_count
      assert_equal 2, client.paths.size
      assert_equal true, client.paths.any? { |p| p.start_with?("company_offer_stats?") }
    end
  end
end
