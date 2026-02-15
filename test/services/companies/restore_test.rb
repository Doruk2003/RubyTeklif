require "test_helper"

module Companies
  class RestoreTest < ActiveSupport::TestCase
    class FakeClient
      attr_reader :last_post_path, :last_post_body

      def initialize(response:)
        @response = response
      end

      def post(path, body:, headers:)
        @last_post_path = path
        @last_post_body = body
        @response
      end
    end

    test "restores via atomic rpc" do
      client = FakeClient.new(response: [{ "company_id" => "cmp-1" }])
      service = Companies::Restore.new(client: client)

      service.call(id: "cmp-1", actor_id: "user-1")

      assert_equal "rpc/restore_company_with_audit_atomic", client.last_post_path
      assert_equal "cmp-1", client.last_post_body[:p_company_id]
      assert_equal "user-1", client.last_post_body[:p_actor_id]
    end

    test "raises when response has error payload" do
      service = Companies::Restore.new(client: FakeClient.new(response: { "message" => "cannot" }))

      assert_raises(ServiceErrors::System) do
        service.call(id: "cmp-1", actor_id: "user-1")
      end
    end
  end
end
