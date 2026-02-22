require "test_helper"

module Admin
  module Users
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

      test "returns first matching user row" do
        row = { "id" => "usr-1", "email" => "a@example.com", "role" => Roles::ADMIN }
        client = FakeClient.new(response: [ row ])

        result = Admin::Users::ShowQuery.new(client: client).call(id: "usr-1")

        assert_equal row, result
        assert_includes client.paths.first, "users?id=eq.usr-1"
      end

      test "raises system error for non-array responses" do
        client = FakeClient.new(response: { "error" => "bad" })

        assert_raises(ServiceErrors::System) do
          Admin::Users::ShowQuery.new(client: client).call(id: "usr-1")
        end
      end
    end
  end
end
