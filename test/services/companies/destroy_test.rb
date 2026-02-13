require "test_helper"

module Companies
  class DestroyTest < ActiveSupport::TestCase
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

    test "archives via atomic rpc" do
      client = FakeClient.new(response: [{ "company_id" => "cmp-1" }])
      service = Companies::Destroy.new(client: client)

      service.call(id: "cmp-1", actor_id: "user-1")

      assert_equal "rpc/archive_company_with_audit_atomic", client.last_post_path
      assert_equal "cmp-1", client.last_post_body[:p_company_id]
    end

    test "raises when response has error payload" do
      service = Companies::Destroy.new(client: FakeClient.new(response: { "message" => "cannot" }))

      assert_raises(ServiceErrors::System) do
        service.call(id: "cmp-1", actor_id: "user-1")
      end
    end
  end
end
