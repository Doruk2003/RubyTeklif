require "test_helper"

module Currencies
  class ServicesTest < ActiveSupport::TestCase
    class FakeClient
      attr_reader :last_post_body, :last_patch_body

      def initialize(post_response: nil, patch_response: nil, delete_response: nil)
        @post_response = post_response
        @patch_response = patch_response
        @delete_response = delete_response
      end

      def post(_path, body:, headers:)
        @last_post_body = body
        @post_response
      end

      def patch(_path, body:, headers:)
        @last_patch_body = body
        @patch_response
      end

      def delete(_path, headers:)
        @delete_response
      end
    end

    class FakeAuditLog
      attr_reader :payload

      def log(**kwargs)
        @payload = kwargs
      end
    end

    def valid_payload
      {
        code: "usd",
        name: "US Dollar",
        symbol: "$",
        rate_to_try: "35.2",
        active: "1"
      }
    end

    test "create returns id and writes audit log" do
      client = FakeClient.new(post_response: [{ "id" => "cur-1" }])
      audit = FakeAuditLog.new
      service = Currencies::Create.new(client: client, audit_log: audit)

      id = service.call(form_payload: valid_payload, actor_id: "usr-1")

      assert_equal "cur-1", id
      assert_equal "USD", client.last_post_body[:code]
      assert_equal "currencies.create", audit.payload[:action]
    end

    test "create raises validation for invalid payload" do
      service = Currencies::Create.new(client: FakeClient.new(post_response: [{ "id" => "cur-1" }]), audit_log: FakeAuditLog.new)

      assert_raises(ServiceErrors::Validation) do
        service.call(form_payload: valid_payload.merge(code: "", rate_to_try: "0"), actor_id: "usr-1")
      end
    end

    test "update raises policy error for forbidden response" do
      client = FakeClient.new(patch_response: { "code" => "42501", "message" => "forbidden" })
      service = Currencies::Update.new(client: client, audit_log: FakeAuditLog.new)

      assert_raises(ServiceErrors::Policy) do
        service.call(id: "cur-1", form_payload: valid_payload, actor_id: "usr-1")
      end
    end

    test "destroy raises system error for generic failure" do
      client = FakeClient.new(delete_response: { "message" => "boom" })
      service = Currencies::Destroy.new(client: client, audit_log: FakeAuditLog.new)

      assert_raises(ServiceErrors::System) do
        service.call(id: "cur-1", actor_id: "usr-1")
      end
    end
  end
end

