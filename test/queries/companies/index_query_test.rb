require "test_helper"

module Companies
  class IndexQueryTest < ActiveSupport::TestCase
    class FakeClient
      attr_reader :paths

      def initialize(companies_response:)
        @companies_response = companies_response
        @paths = []
      end

      def get(path)
        @paths << path
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
      assert_match(/\Acompany_with_offer_counts\?/, path)
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
        { "id" => "cmp-2", "name" => "B", "active" => true, "offers_count" => 2 }
      ]
      client = FakeClient.new(companies_response: companies)
      query = Companies::IndexQuery.new(client: client)

      result = query.call(params: { has_offers: "1", sort: "offers_count", dir: "desc" })

      assert_equal 1, result[:items].size
      assert_equal "cmp-2", result[:items].first.id
      assert_equal 2, result[:items].first.offers_count
      assert_equal 1, client.paths.size
      path = client.paths.first
      assert_includes path, "offers_count=gt.0"
      assert_includes path, "order=offers_count.desc"
    end
  end
end
