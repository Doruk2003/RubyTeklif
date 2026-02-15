require "test_helper"

module Admin
  module ActivityLogs
    class IndexQueryTest < ActiveSupport::TestCase
      class FakeClient
        attr_reader :paths

        def initialize(logs_response:, filter_options_response: nil)
          @logs_response = logs_response
          @filter_options_response = filter_options_response || logs_response
          @paths = []
        end

        def get(path)
          @paths << path
          return @filter_options_response if path.start_with?("activity_logs?select=action,target_type")

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
        filter_options = logs + target_types
        client = FakeClient.new(logs_response: logs, filter_options_response: filter_options)
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
