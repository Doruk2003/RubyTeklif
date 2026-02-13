require "test_helper"

module Companies
  class CreateTest < ActiveSupport::TestCase
    class FakeClient
      attr_reader :posted_path, :posted_body

      def initialize(post_response:)
        @post_response = post_response
      end

      def post(path, body:, headers:)
        @posted_path = path
        @posted_body = body
        @post_response
      end
    end

    test "creates company via atomic rpc" do
      client = FakeClient.new(post_response: [{ "company_id" => "cmp-1" }])
      service = Companies::Create.new(client: client)

      result = service.call(
        form_payload: { name: "Acme", tax_number: "12345678", active: "1" },
        actor_id: "user-1"
      )

      assert_equal "cmp-1", result[:id]
      assert_equal "Acme musterisi olusturuldu.", result[:notice]
      assert_equal "rpc/create_company_with_audit_atomic", client.posted_path
      assert_equal "user-1", client.posted_body[:p_actor_id]
      assert_equal true, client.posted_body[:p_active]
    end

    test "raises for duplicate tax number" do
      duplicate = {
        "code" => "23505",
        "message" => "duplicate key value violates unique constraint companies_user_tax_number_idx"
      }
      client = FakeClient.new(post_response: duplicate)
      service = Companies::Create.new(client: client)

      error = assert_raises(ServiceErrors::Validation) do
        service.call(form_payload: { name: "Acme", tax_number: "12345678", active: "1" }, actor_id: "user-1")
      end

      assert_includes error.message, "vergi numarasi"
    end
  end
end
