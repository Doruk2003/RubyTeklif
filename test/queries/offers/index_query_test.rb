require "test_helper"

module Offers
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
      rows = Array.new(3) { |i| { "id" => "off-#{i + 1}" } }
      client = FakeClient.new(response: rows)
      result = Offers::IndexQuery.new(client: client).call(params: { page: "2", per_page: "2" })

      assert_equal 2, result[:items].size
      assert_equal true, result[:has_next]
      assert_equal true, result[:has_prev]
      assert_includes client.paths.first, "limit=3"
      assert_includes client.paths.first, "offset=2"
    end
  end
end

