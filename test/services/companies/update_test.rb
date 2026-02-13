require "test_helper"

module Companies
  class UpdateTest < ActiveSupport::TestCase
    class FakeClient
      def initialize(response:)
        @response = response
      end

      def patch(_path, body:, headers:)
        @last_body = body
        @response
      end

      attr_reader :last_body
    end

    class FakeAuditLog
      attr_reader :payload

      def log(**kwargs)
        @payload = kwargs
      end
    end

    test "updates company and logs action" do
      client = FakeClient.new(response: [{ "id" => "cmp-1" }])
      audit_log = FakeAuditLog.new
      service = Companies::Update.new(client: client, audit_log: audit_log)

      payload = service.call(id: "cmp-1", form_payload: { name: "New Co", tax_number: "12345678", active: "0" }, actor_id: "user-1")

      assert_equal false, payload[:active]
      assert_equal "companies.update", audit_log.payload[:action]
      assert_equal "cmp-1", audit_log.payload[:target_id]
      assert_equal "New Co", client.last_body[:name]
    end

    test "raises when update response has error payload" do
      client = FakeClient.new(response: { "message" => "boom" })
      service = Companies::Update.new(client: client, audit_log: FakeAuditLog.new)

      assert_raises(ServiceErrors::System) do
        service.call(id: "cmp-1", form_payload: { name: "X", tax_number: "12345678", active: "1" }, actor_id: "user-1")
      end
    end
  end
end
