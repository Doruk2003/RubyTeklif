require "test_helper"

module Admin
  module Users
    class EmailIndexQueryTest < ActiveSupport::TestCase
      class FakeClient
        def initialize(response:)
          @response = response
        end

        def get(path)
          @response
        end
      end

      test "returns id-email hash index" do
        rows = [
          { "id" => "usr-1", "email" => "a@example.com" },
          { "id" => "usr-2", "email" => "b@example.com" }
        ]
        client = FakeClient.new(response: rows)

        result = Admin::Users::EmailIndexQuery.new(client: client).call

        assert_equal(
          {
            "usr-1" => "a@example.com",
            "usr-2" => "b@example.com"
          },
          result
        )
      end

      test "raises system error on non-array response" do
        client = FakeClient.new(response: { "error" => "bad" })

        assert_raises(ServiceErrors::System) do
          Admin::Users::EmailIndexQuery.new(client: client).call
        end
      end
    end
  end
end
