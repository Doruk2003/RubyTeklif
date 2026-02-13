require "test_helper"

module Offers
  class FormQueryTest < ActiveSupport::TestCase
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

    test "builds filtered product query with company and category" do
      client = FakeClient.new(response: [])
      query = Offers::FormQuery.new(client: client)

      query.products(company_id: "cmp-1", category: "service")
      path = client.paths.first

      assert_includes path, "active=eq.true"
      assert_includes path, "company_id=eq.cmp-1"
      assert_includes path, "category=eq.service"
    end

    test "ignores unsupported category" do
      client = FakeClient.new(response: [])
      query = Offers::FormQuery.new(client: client)

      query.products(company_id: "", category: "invalid")
      path = client.paths.first

      assert_includes path, "active=eq.true"
      refute_includes path, "category=eq.invalid"
    end
  end
end
