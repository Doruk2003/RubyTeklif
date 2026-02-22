require "test_helper"

module Categories
  class OptionsQueryTest < ActiveSupport::TestCase
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

    test "returns rows for valid array response" do
      rows = [{ "id" => "cat-1", "name" => "Service" }]
      client = FakeClient.new(response: rows)

      result = Categories::OptionsQuery.new(client: client).call(active_only: true, user_id: "usr-1")

      assert_equal rows, result
      assert_includes client.paths.first, "active=eq.true"
    end

    test "raises system error for non-array response" do
      client = FakeClient.new(response: { "error" => "bad" })

      assert_raises(ServiceErrors::System) do
        Categories::OptionsQuery.new(client: client).call(active_only: false, user_id: "usr-1")
      end
    end
  end
end
