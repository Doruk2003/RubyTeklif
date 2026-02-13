require "test_helper"

module Companies
  class CreateTest < ActiveSupport::TestCase
    class FakeClient
      attr_reader :posted_path, :posted_body

      def initialize(post_response:, exists: true, fallback_id: nil)
        @post_response = post_response
        @exists = exists
        @fallback_id = fallback_id
      end

      def post(path, body:, headers:)
        @posted_path = path
        @posted_body = body
        @post_response
      end

      def get(path)
        if path.include?("select=id&limit=1")
          return @exists ? [{ "id" => "cmp-1" }] : []
        end

        if path.include?("tax_number=eq.") && @fallback_id
          return [{ "id" => @fallback_id }]
        end

        []
      end
    end

    class FakeAuditLog
      attr_reader :payload

      def log(**kwargs)
        @payload = kwargs
      end
    end

    test "creates company and writes audit log" do
      client = FakeClient.new(post_response: [{ "id" => "cmp-1" }], exists: true)
      audit_log = FakeAuditLog.new
      service = Companies::Create.new(client: client, audit_log: audit_log)

      result = service.call(
        form_payload: { name: "Acme", tax_number: "12345678", active: "1" },
        actor_id: "user-1"
      )

      assert_equal "cmp-1", result[:id]
      assert_equal "Acme musterisi olusturuldu.", result[:notice]
      assert_equal "companies", client.posted_path
      assert_equal "user-1", client.posted_body[:user_id]
      assert_equal true, client.posted_body[:active]
      assert_equal "companies.create", audit_log.payload[:action]
      assert_equal "company", audit_log.payload[:target_type]
    end

    test "raises for duplicate tax number" do
      duplicate = {
        "code" => "23505",
        "message" => "duplicate key value violates unique constraint companies_user_tax_number_idx"
      }
      client = FakeClient.new(post_response: duplicate)
      service = Companies::Create.new(client: client, audit_log: FakeAuditLog.new)

      error = assert_raises(ServiceErrors::Validation) do
        service.call(form_payload: { name: "Acme", tax_number: "12345678", active: "1" }, actor_id: "user-1")
      end

      assert_includes error.message, "vergi numarasi"
    end
  end
end
