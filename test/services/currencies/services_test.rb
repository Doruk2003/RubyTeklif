require "test_helper"

module Currencies
  class ServicesTest < ActiveSupport::TestCase
    class FakeClient
      attr_reader :last_post_path, :last_post_body

      def initialize(post_response: nil, get_response: [])
        @post_response = post_response
        @get_response = get_response
      end

      def get(path)
        return @get_response.call(path) if @get_response.respond_to?(:call)

        @get_response
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
      client = FakeClient.new(post_response: [{ "currency_id" => "cur-1" }], get_response: [])
      service = Currencies::Create.new(client: client)

      id = service.call(form_payload: valid_payload, actor_id: "usr-1")

      assert_equal "cur-1", id
      assert_equal "rpc/create_currency_with_audit_atomic", client.last_post_path
      assert_equal "USD", client.last_post_body[:p_code]
      assert_equal "usr-1", client.last_post_body[:p_actor_id]
    end

    test "create raises validation for invalid payload" do
      service = Currencies::Create.new(client: FakeClient.new(post_response: [{ "currency_id" => "cur-1" }], get_response: []))

      assert_raises(ServiceErrors::Validation) do
        service.call(form_payload: valid_payload.merge(code: "", rate_to_try: "0"), actor_id: "usr-1")
      end
    end

    test "update raises policy error for forbidden response" do
      client = FakeClient.new(post_response: { "code" => "42501", "message" => "forbidden" }, get_response: [])
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

    test "restore calls atomic rpc endpoint" do
      client = FakeClient.new(post_response: [{ "currency_id" => "cur-1" }], get_response: [])
      service = Currencies::Restore.new(client: client)

      service.call(id: "cur-1", actor_id: "usr-1")

      assert_equal "rpc/restore_currency_with_audit_atomic", client.last_post_path
      assert_equal "cur-1", client.last_post_body[:p_currency_id]
      assert_equal "usr-1", client.last_post_body[:p_actor_id]
    end

    test "create prevents duplicate currency code before rpc" do
      client = FakeClient.new(
        post_response: [{ "currency_id" => "cur-1" }],
        get_response: [{ "id" => "cur-existing" }]
      )
      service = Currencies::Create.new(client: client)

      assert_raises(ServiceErrors::Validation) do
        service.call(form_payload: valid_payload, actor_id: "usr-1")
      end

      assert_nil client.last_post_path
    end

    test "update prevents duplicate currency code before rpc" do
      client = FakeClient.new(
        post_response: [{ "currency_id" => "cur-1" }],
        get_response: lambda { |path|
          if path.include?("id=neq.cur-1")
            [{ "id" => "cur-other" }]
          else
            []
          end
        }
      )
      service = Currencies::Update.new(client: client)

      assert_raises(ServiceErrors::Validation) do
        service.call(id: "cur-1", form_payload: valid_payload, actor_id: "usr-1")
      end

      assert_nil client.last_post_path
    end
  end
end
