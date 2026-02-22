require "test_helper"

module Categories
  class ServicesTest < ActiveSupport::TestCase
    class FakeClient
      attr_reader :last_post_path, :last_post_body

      def initialize(post_response:, get_response: [])
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

    test "create returns id via atomic rpc" do
      client = FakeClient.new(post_response: [{ "category_id" => "cat-1" }], get_response: [])
      service = Categories::Create.new(client: client)

      id = service.call(
        form_payload: { code: "raw_material", name: "Raw Material", active: "1" },
        actor_id: "usr-1"
      )

      assert_equal "cat-1", id
      assert_equal "rpc/create_category_with_audit_atomic", client.last_post_path
      assert_equal "usr-1", client.last_post_body[:p_actor_id]
      assert_equal "raw_material", client.last_post_body[:p_code]
      assert_equal true, client.last_post_body[:p_active]
    end

    test "create raises validation for invalid payload" do
      service = Categories::Create.new(client: FakeClient.new(post_response: [{ "category_id" => "cat-1" }], get_response: []))

      assert_raises(ServiceErrors::Validation) do
        service.call(form_payload: { code: "", name: "", active: "1" }, actor_id: "usr-1")
      end
    end

    test "create raises policy error for forbidden response" do
      client = FakeClient.new(post_response: { "code" => "42501", "message" => "forbidden" }, get_response: [])
      service = Categories::Create.new(client: client)

      assert_raises(ServiceErrors::Policy) do
        service.call(form_payload: { code: "raw_material", name: "Raw Material", active: "1" }, actor_id: "usr-1")
      end
    end

    test "update calls atomic rpc" do
      client = FakeClient.new(post_response: [{ "category_id" => "cat-1" }], get_response: [])
      service = Categories::Update.new(client: client)

      result = service.call(
        id: "cat-1",
        form_payload: { code: "service", name: "Service", active: "1" },
        actor_id: "usr-1"
      )

      assert_equal "cat-1", result[:id]
      assert_equal "rpc/update_category_with_audit_atomic", client.last_post_path
      assert_equal "usr-1", client.last_post_body[:p_actor_id]
      assert_equal "cat-1", client.last_post_body[:p_category_id]
    end

    test "destroy calls archive rpc" do
      client = FakeClient.new(post_response: [{ "category_id" => "cat-1" }])
      service = Categories::Destroy.new(client: client)

      service.call(id: "cat-1", actor_id: "usr-1")

      assert_equal "rpc/archive_category_with_audit_atomic", client.last_post_path
      assert_equal "cat-1", client.last_post_body[:p_category_id]
    end

    test "restore calls restore rpc" do
      client = FakeClient.new(post_response: [{ "category_id" => "cat-1" }])
      service = Categories::Restore.new(client: client)

      service.call(id: "cat-1", actor_id: "usr-1")

      assert_equal "rpc/restore_category_with_audit_atomic", client.last_post_path
      assert_equal "cat-1", client.last_post_body[:p_category_id]
    end

    test "create prevents duplicate category code or name before rpc" do
      client = FakeClient.new(
        post_response: [{ "category_id" => "cat-1" }],
        get_response: lambda { |path|
          if path.include?("code=eq.raw_material")
            [{ "id" => "cat-existing" }]
          else
            []
          end
        }
      )
      service = Categories::Create.new(client: client)

      assert_raises(ServiceErrors::Validation) do
        service.call(form_payload: { code: "raw_material", name: "Raw Material", active: "1" }, actor_id: "usr-1")
      end

      assert_nil client.last_post_path
    end

    test "update prevents duplicate category code or name before rpc" do
      client = FakeClient.new(
        post_response: [{ "category_id" => "cat-1" }],
        get_response: lambda { |path|
          if path.include?("id=neq.cat-1") && path.include?("name=eq.Service")
            [{ "id" => "cat-other" }]
          else
            []
          end
        }
      )
      service = Categories::Update.new(client: client)

      assert_raises(ServiceErrors::Validation) do
        service.call(
          id: "cat-1",
          form_payload: { code: "service", name: "Service", active: "1" },
          actor_id: "usr-1"
        )
      end

      assert_nil client.last_post_path
    end
  end
end
