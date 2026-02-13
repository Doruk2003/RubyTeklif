require "test_helper"

module Currencies
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
      rows = Array.new(4) { |i| { "id" => "cur-#{i + 1}" } }
      client = FakeClient.new(response: rows)
      result = Currencies::IndexQuery.new(client: client).call(params: { page: "1", per_page: "3" })

      assert_equal 3, result[:items].size
      assert_equal true, result[:has_next]
      assert_equal false, result[:has_prev]
      assert_includes client.paths.first, "limit=4"
      assert_includes client.paths.first, "offset=0"
    end
  end
end

