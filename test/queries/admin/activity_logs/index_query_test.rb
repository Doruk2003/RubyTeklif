require "test_helper"

module Admin
  module ActivityLogs
    class IndexQueryTest < ActiveSupport::TestCase
      class FakeClient
        attr_reader :paths

        def initialize(logs_response:, actions_response: nil)
          @logs_response = logs_response
          @actions_response = actions_response || logs_response
          @paths = []
        end

        def get(path)
          @paths << path
          return @actions_response if path.start_with?("activity_logs?select=action")

          @logs_response
        end
      end

      test "returns paged logs and dynamic action options" do
        logs = [
          { "id" => "log-1", "action" => "users.create" },
          { "id" => "log-2", "action" => "offers.create" },
          { "id" => "log-3", "action" => "offers.create" }
        ]
        client = FakeClient.new(logs_response: logs)
        query = Admin::ActivityLogs::IndexQuery.new(client: client)

        result = query.call(params: { action: "offers.create", page: "1", per_page: "2" })
        actions = query.action_options

        assert_equal 2, result[:items].size
        assert_equal true, result[:has_next]
        assert_equal false, result[:has_prev]
        assert_includes client.paths.first, "action=eq.offers.create"
        assert_equal ["users.create", "offers.create"], actions
      end
    end
  end
end

