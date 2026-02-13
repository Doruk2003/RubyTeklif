require "test_helper"

module Companies
  class DestroyTest < ActiveSupport::TestCase
    class FakeClient
      def initialize(response:)
        @response = response
      end

      def patch(_path, body:, headers:)
        @response
      end
    end

    class FakeAuditLog
      attr_reader :payload

      def log(**kwargs)
        @payload = kwargs
      end
    end

    test "archives and logs action" do
      audit_log = FakeAuditLog.new
      service = Companies::Destroy.new(client: FakeClient.new(response: []), audit_log: audit_log)

      service.call(id: "cmp-1", actor_id: "user-1")

      assert_equal "companies.archive", audit_log.payload[:action]
      assert_equal "cmp-1", audit_log.payload[:target_id]
    end

    test "raises when response has error payload" do
      service = Companies::Destroy.new(client: FakeClient.new(response: { "message" => "cannot" }), audit_log: FakeAuditLog.new)

      assert_raises(ServiceErrors::System) do
        service.call(id: "cmp-1", actor_id: "user-1")
      end
    end
  end
end
