require "test_helper"

module Admin
  module ActivityLogs
    class IndexQueryTest < ActiveSupport::TestCase
      class FakeClient
        attr_reader :paths

        def initialize(logs_response:, actions_response: nil, target_types_response: nil)
          @logs_response = logs_response
          @actions_response = actions_response || logs_response
          @target_types_response = target_types_response || logs_response
          @paths = []
        end

        def get(path)
          @paths << path
          return @actions_response if path.start_with?("activity_logs?select=action")
          return @target_types_response if path.start_with?("activity_logs?select=target_type")

          @logs_response
        end
      end

      test "returns paged logs and dynamic action options" do
        logs = [
          { "id" => "log-1", "action" => "users.create" },
          { "id" => "log-2", "action" => "offers.create" },
          { "id" => "log-3", "action" => "offers.create" }
        ]
        target_types = [
          { "target_type" => "user" },
          { "target_type" => "offer" },
          { "target_type" => "offer" }
        ]
        client = FakeClient.new(logs_response: logs, target_types_response: target_types)
        query = Admin::ActivityLogs::IndexQuery.new(client: client)

        result = query.call(params: { action: "offers.create", target_type: "offer", page: "1", per_page: "2" })
        actions = query.action_options
        target_type_options = query.target_type_options

        assert_equal 2, result[:items].size
        assert_equal true, result[:has_next]
        assert_equal false, result[:has_prev]
        assert_includes client.paths.first, "action=eq.offers.create"
        assert_includes client.paths.first, "target_type=eq.offer"
        assert_equal ["users.create", "offers.create"], actions
        assert_equal ["user", "offer"], target_type_options
      end
    end
  end
end
