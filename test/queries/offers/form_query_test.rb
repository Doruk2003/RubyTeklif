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

      query.products(category_id: "cat-1", user_id: "usr-1")
      path = client.paths.first

      assert_includes path, "active=eq.true"
      assert_includes path, "category_id=eq.cat-1"
    end

    test "omits category filter when blank" do
      client = FakeClient.new(response: [])
      query = Offers::FormQuery.new(client: client)

      query.products(category_id: "", user_id: "usr-1")
      path = client.paths.first

      assert_includes path, "active=eq.true"
      refute_includes path, "category_id=eq."
    end

    test "builds companies query" do
      client = FakeClient.new(response: [])
      query = Offers::FormQuery.new(client: client)

      query.companies(user_id: "usr-1")
      path = client.paths.first

      assert_includes path, "companies?deleted_at=is.null"
      assert_includes path, "order=name.asc"
    end

    test "raises system error for non-array companies response" do
      client = FakeClient.new(response: { "error" => "bad" })
      query = Offers::FormQuery.new(client: client)

      assert_raises(ServiceErrors::System) do
        query.companies(user_id: "usr-1")
      end
    end

    test "raises system error for non-array products response" do
      client = FakeClient.new(response: { "error" => "bad" })
      query = Offers::FormQuery.new(client: client)

      assert_raises(ServiceErrors::System) do
        query.products(category_id: "cat-1", user_id: "usr-1")
      end
    end
  end
end
