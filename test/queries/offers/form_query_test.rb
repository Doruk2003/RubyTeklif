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

    test "builds filtered product query with category id" do
      client = FakeClient.new(response: [])
      query = Offers::FormQuery.new(client: client)

      query.products(category_id: "cat-1")
      path = client.paths.first

      assert_includes path, "active=eq.true"
      assert_includes path, "category_id=eq.cat-1"
    end

    test "omits category filter when blank" do
      client = FakeClient.new(response: [])
      query = Offers::FormQuery.new(client: client)

      query.products(category_id: "")
      path = client.paths.first

      assert_includes path, "active=eq.true"
      refute_includes path, "category_id=eq."
    end
  end
end
