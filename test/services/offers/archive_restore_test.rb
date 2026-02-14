require "test_helper"

module Offers
  class ArchiveRestoreTest < ActiveSupport::TestCase
    class FakeClient
      attr_reader :last_post_path, :last_post_body

      def initialize(post_response:)
        @post_response = post_response
      end

      def post(path, body:, headers:)
        @last_post_path = path
        @last_post_body = body
        @post_response
      end
    end

    test "destroy calls archive atomic rpc" do
      client = FakeClient.new(post_response: [{ "offer_id" => "off-1" }])
      service = Offers::Destroy.new(client: client)

      service.call(id: "off-1", actor_id: "usr-1")

      assert_equal "rpc/archive_offer_with_items_and_audit_atomic", client.last_post_path
      assert_equal "off-1", client.last_post_body[:p_offer_id]
      assert_equal "usr-1", client.last_post_body[:p_actor_id]
    end

    test "restore calls restore atomic rpc" do
      client = FakeClient.new(post_response: [{ "offer_id" => "off-1" }])
      service = Offers::Restore.new(client: client)

      service.call(id: "off-1", actor_id: "usr-1")

      assert_equal "rpc/restore_offer_with_items_and_audit_atomic", client.last_post_path
      assert_equal "off-1", client.last_post_body[:p_offer_id]
      assert_equal "usr-1", client.last_post_body[:p_actor_id]
    end

    test "destroy raises system for generic failure payload" do
      service = Offers::Destroy.new(client: FakeClient.new(post_response: { "message" => "boom" }))

      assert_raises(ServiceErrors::System) do
        service.call(id: "off-1", actor_id: "usr-1")
      end
    end

    test "restore raises policy for forbidden payload" do
      service = Offers::Restore.new(client: FakeClient.new(post_response: { "code" => "42501", "message" => "forbidden" }))

      assert_raises(ServiceErrors::Policy) do
        service.call(id: "off-1", actor_id: "usr-1")
      end
    end
  end
end
