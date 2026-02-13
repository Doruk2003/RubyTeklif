require "test_helper"

module Admin
  module Users
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

      test "builds filtered paged query and returns pagination metadata" do
        rows = Array.new(3) { |i| { "id" => "usr-#{i}" } }
        client = FakeClient.new(response: rows)
        result = Admin::Users::IndexQuery.new(client: client).call(
          params: { q: "foo", role: Roles::SALES, active: "true", page: "2", per_page: "2" }
        )

        path = client.paths.first
        assert_includes path, "email=ilike.*foo*"
        assert_includes path, "role=eq.sales"
        assert_includes path, "active=eq.true"
        assert_includes path, "limit=3"
        assert_includes path, "offset=2"
        assert_equal true, result[:has_next]
        assert_equal true, result[:has_prev]
        assert_equal 2, result[:items].size
      end
    end
  end
end

