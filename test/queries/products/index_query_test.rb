require "test_helper"

module Products
  class IndexQueryTest < ActiveSupport::TestCase
    class FakeClient
      attr_reader :paths

      def initialize(response:)
        @response = response
        @paths = []
      end

      def get(path)
        @paths << path
        @response
      end
    end

    test "returns pagination metadata and builds paged query" do
      rows = Array.new(6) { |i| { "id" => "prd-#{i + 1}" } }
      client = FakeClient.new(response: rows)
      result = Products::IndexQuery.new(client: client).call(params: { page: "2", per_page: "5", category: "service" })

      assert_equal 5, result[:items].size
      assert_equal true, result[:has_next]
      assert_equal true, result[:has_prev]
      assert_includes client.paths.first, "category"
      assert_includes client.paths.first, "category=eq.service"
      assert_includes client.paths.first, "limit=6"
      assert_includes client.paths.first, "offset=5"
    end
  end
end
