require "test_helper"

module Brands
  class CreateTest < ActiveSupport::TestCase
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

    test "creates brand via atomic rpc" do
      client = FakeClient.new(post_response: [{ "brand_id" => "brd-1" }], get_response: [])
      service = Brands::Create.new(client: client)

      id = service.call(form_payload: { code: "ELE-001", name: "Elektrik", active: "1" }, actor_id: "usr-1")

      assert_equal "brd-1", id
      assert_equal "rpc/create_brand_with_audit_atomic", client.last_post_path
      assert_equal "usr-1", client.last_post_body[:p_actor_id]
    end

    test "prevents duplicate brand code or name before rpc" do
      client = FakeClient.new(
        post_response: [{ "brand_id" => "brd-1" }],
        get_response: lambda { |path|
          if path.include?("name=eq.Elektrik")
            [{ "id" => "brd-existing" }]
          else
            []
          end
        }
      )
      service = Brands::Create.new(client: client)

      assert_raises(ServiceErrors::Validation) do
        service.call(form_payload: { code: "ELE-001", name: "Elektrik", active: "1" }, actor_id: "usr-1")
      end

      assert_nil client.last_post_path
    end
  end
end
