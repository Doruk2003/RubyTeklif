require "test_helper"

module Companies
  class UpdateTest < ActiveSupport::TestCase
    class FakeClient
      attr_reader :last_post_path, :last_post_body, :last_get_path

      def initialize(response:, get_response: [])
        @response = response
        @get_response = get_response
      end

      def get(path)
        @last_get_path = path
        @get_response
      end

      def post(path, body:, headers:)
        @last_post_path = path
        @last_post_body = body
        @response
      end
    end

    test "updates company via atomic rpc" do
      client = FakeClient.new(response: [{ "company_id" => "cmp-1" }], get_response: [])
      service = Companies::Update.new(client: client)

      payload = service.call(id: "cmp-1", form_payload: { name: "New Co", tax_number: "12345678", active: "0" }, actor_id: "user-1")

      assert_equal false, payload[:active]
      assert_equal "rpc/update_company_with_audit_atomic", client.last_post_path
      assert_equal "cmp-1", client.last_post_body[:p_company_id]
      assert_equal "New Co", client.last_post_body[:p_name]
      assert_includes client.last_get_path, "id=neq.cmp-1"
    end

    test "raises when update response has error payload" do
      client = FakeClient.new(response: { "message" => "boom" }, get_response: [])
      service = Companies::Update.new(client: client)

      assert_raises(ServiceErrors::System) do
        service.call(id: "cmp-1", form_payload: { name: "X", tax_number: "12345678", active: "1" }, actor_id: "user-1")
      end
    end

    test "raises validation when tax number is already used by another company" do
      client = FakeClient.new(response: [{ "company_id" => "cmp-1" }], get_response: [{ "id" => "cmp-2" }])
      service = Companies::Update.new(client: client)

      assert_raises(ServiceErrors::Validation) do
        service.call(id: "cmp-1", form_payload: { name: "X", tax_number: "12345678", active: "1" }, actor_id: "user-1")
      end

      assert_nil client.last_post_path
    end
  end
end
