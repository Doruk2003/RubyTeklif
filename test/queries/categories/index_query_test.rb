require "test_helper"

module Categories
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
      rows = Array.new(4) { |i| { "id" => "cat-#{i + 1}" } }
      client = FakeClient.new(response: rows)

      result = Categories::IndexQuery.new(client: client).call(params: { page: "1", per_page: "3", scope: "active" })

      assert_equal 3, result[:items].size
      assert_equal true, result[:has_next]
      assert_equal false, result[:has_prev]
      assert_equal "active", result[:scope]
      assert_includes client.paths.first, "deleted_at=is.null"
      assert_includes client.paths.first, "limit=4"
      assert_includes client.paths.first, "offset=0"
    end

    test "applies search active filter and sort params" do
      client = FakeClient.new(response: [])

      result = Categories::IndexQuery.new(client: client).call(
        params: { q: "servis", active: "0", sort: "code", dir: "desc", scope: "all" }
      )

      assert_equal "servis", result[:q]
      assert_equal "0", result[:active]
      assert_equal "code", result[:sort]
      assert_equal "desc", result[:dir]
      assert_includes client.paths.first, "active=eq.false"
      assert_includes client.paths.first, "or=(name.ilike.*servis*,code.ilike.*servis*)"
      assert_includes client.paths.first, "order=code.desc"
      refute_includes client.paths.first, "deleted_at=is.null"
      refute_includes client.paths.first, "deleted_at=not.is.null"
    end
  end
end
