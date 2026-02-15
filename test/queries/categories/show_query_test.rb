require "test_helper"

module Categories
  class ShowQueryTest < ActiveSupport::TestCase
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

    test "returns first category row and escapes id filter value" do
      row = { "id" => "cat-1", "code" => "service", "name" => "Service" }
      client = FakeClient.new(response: [ row ])

      result = Categories::ShowQuery.new(client: client).call("cat-1")

      assert_equal row, result
      assert_includes client.paths.first, "id=eq.#{Supabase::FilterValue.eq("cat-1")}"
    end

    test "returns nil when response is not an array" do
      client = FakeClient.new(response: { "error" => "bad" })

      result = Categories::ShowQuery.new(client: client).call("cat-1")

      assert_nil result
    end
  end
end
