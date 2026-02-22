require "test_helper"

module Currencies
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
      rows = [{ "id" => "cur-1", "code" => "USD" }]
      client = FakeClient.new(response: rows)

      result = Currencies::OptionsQuery.new(client: client).call(active_only: true, user_id: "usr-1")

      assert_equal rows, result
      assert_includes client.paths.first, "active=eq.true"
    end

    test "raises system error for non-array response" do
      client = FakeClient.new(response: { "error" => "bad" })

      assert_raises(ServiceErrors::System) do
        Currencies::OptionsQuery.new(client: client).call(active_only: false, user_id: "usr-1")
      end
    end
  end
end
