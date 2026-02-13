require "test_helper"

module Currencies
  class ServicesTest < ActiveSupport::TestCase
    class FakeClient
      attr_reader :last_post_path, :last_post_body

      def initialize(post_response: nil)
        @post_response = post_response
      end

      def post(path, body:, headers:)
        @last_post_path = path
        @last_post_body = body
        @post_response
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

    test "create returns id via atomic rpc" do
      client = FakeClient.new(post_response: [{ "currency_id" => "cur-1" }])
      service = Currencies::Create.new(client: client)

      id = service.call(form_payload: valid_payload, actor_id: "usr-1")

      assert_equal "cur-1", id
      assert_equal "rpc/create_currency_with_audit_atomic", client.last_post_path
      assert_equal "USD", client.last_post_body[:p_code]
      assert_equal "usr-1", client.last_post_body[:p_actor_id]
    end

    test "create raises validation for invalid payload" do
      service = Currencies::Create.new(client: FakeClient.new(post_response: [{ "currency_id" => "cur-1" }]))

      assert_raises(ServiceErrors::Validation) do
        service.call(form_payload: valid_payload.merge(code: "", rate_to_try: "0"), actor_id: "usr-1")
      end
    end

    test "update raises policy error for forbidden response" do
      client = FakeClient.new(post_response: { "code" => "42501", "message" => "forbidden" })
      service = Currencies::Update.new(client: client)

      assert_raises(ServiceErrors::Policy) do
        service.call(id: "cur-1", form_payload: valid_payload, actor_id: "usr-1")
      end
    end

    test "destroy raises system error for generic failure" do
      client = FakeClient.new(post_response: { "message" => "boom" })
      service = Currencies::Destroy.new(client: client)

      assert_raises(ServiceErrors::System) do
        service.call(id: "cur-1", actor_id: "usr-1")
      end
    end
  end
end
