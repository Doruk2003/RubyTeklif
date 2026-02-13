require "test_helper"

module Products
  class ServicesTest < ActiveSupport::TestCase
    class FakeClient
      attr_reader :last_post_path, :last_post_body, :last_patch_path, :last_patch_body

      def initialize(post_response: nil, patch_response: nil, delete_response: nil)
        @post_response = post_response
        @patch_response = patch_response
        @delete_response = delete_response
      end

      def post(path, body:, headers:)
        @last_post_path = path
        @last_post_body = body
        @post_response
      end

      def patch(path, body:, headers:)
        @last_patch_path = path
        @last_patch_body = body
        @patch_response
      end

      def delete(_path, headers:)
        @delete_response
      end
    end

    class FakeAuditLog
      def log(**kwargs); end
    end

    def valid_payload
      {
        name: "Urun A",
        price: "10.5",
        vat_rate: "20",
        item_type: "product",
        category_id: "11111111-1111-1111-1111-111111111111",
        active: "1"
      }
    end

    test "create returns id via rpc" do
      client = FakeClient.new(post_response: [{ "product_id" => "prd-1" }])
      service = Products::Create.new(client: client)

      id = service.call(form_payload: valid_payload, actor_id: "usr-1")

      assert_equal "prd-1", id
      assert_equal "rpc/create_product_with_audit_atomic", client.last_post_path
      assert_equal "usr-1", client.last_post_body[:p_actor_id]
    end

    test "create raises validation for invalid payload" do
      service = Products::Create.new(client: FakeClient.new(post_response: [{ "product_id" => "prd-1" }]))

      assert_raises(ServiceErrors::Validation) do
        service.call(form_payload: valid_payload.merge(name: "", price: "-1"), actor_id: "usr-1")
      end
    end

    test "create raises validation when category is missing" do
      service = Products::Create.new(client: FakeClient.new(post_response: [{ "product_id" => "prd-1" }]))

      assert_raises(ServiceErrors::Validation) do
        service.call(form_payload: valid_payload.merge(category_id: ""), actor_id: "usr-1")
      end
    end

    test "update raises policy error for forbidden response" do
      client = FakeClient.new(post_response: { "code" => "42501", "message" => "forbidden" })
      service = Products::Update.new(client: client)

      assert_raises(ServiceErrors::Policy) do
        service.call(id: "prd-1", form_payload: valid_payload, actor_id: "usr-1")
      end
    end

    test "destroy raises system error for generic failure" do
      client = FakeClient.new(delete_response: { "message" => "boom" })
      service = Products::Destroy.new(client: client, audit_log: FakeAuditLog.new)

      assert_raises(ServiceErrors::System) do
        service.call(id: "prd-1", actor_id: "usr-1")
      end
    end
  end
end
