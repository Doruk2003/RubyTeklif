require "test_helper"

module Admin
  module Users
    class ServicesTest < ActiveSupport::TestCase
      class FakeClient
        def initialize(post_response: nil, patch_response: nil, get_response: nil)
          @post_response = post_response
          @patch_response = patch_response
          @get_response = get_response
        end

        def post(_path, body:, headers:)
          @post_response
        end

        def patch(_path, body:, headers:)
          @patch_response
        end

        def get(_path)
          @get_response
        end
      end

      class FakeAuth
        def initialize(create_user_response: nil, recovery_ok: true)
          @create_user_response = create_user_response
          @recovery_ok = recovery_ok
        end

        def create_user(email:, password:, role:)
          @create_user_response
        end

        def send_recovery(email:)
          raise Supabase::Auth::AuthError, "mail error" unless @recovery_ok

          {}
        end
      end

      class FakeAuditLog
        attr_reader :payload

        def log(**kwargs)
          @payload = kwargs
        end
      end

      test "create user inserts role row and logs action" do
        client = FakeClient.new(post_response: [])
        auth = FakeAuth.new(create_user_response: { "id" => "usr-2" })
        audit = FakeAuditLog.new

        user_id = Admin::Users::Create.new(client: client, auth: auth, audit_log: audit).call(
          form_payload: { email: "test@example.com", password: "Password12", role: Roles::SALES },
          actor_id: "usr-1"
        )

        assert_equal "usr-2", user_id
        assert_equal "users.create", audit.payload[:action]
      end

      test "update role raises policy error for forbidden response" do
        client = FakeClient.new(patch_response: { "code" => "42501", "message" => "forbidden" })
        service = Admin::Users::UpdateRole.new(client: client, audit_log: FakeAuditLog.new)

        assert_raises(ServiceErrors::Policy) do
          service.call(id: "usr-2", role: Roles::FINANCE, actor_id: "usr-1")
        end
      end

      test "set active works for disable" do
        service = Admin::Users::SetActive.new(client: FakeClient.new(patch_response: []), audit_log: FakeAuditLog.new)

        result = service.call(id: "usr-2", active: false, actor_id: "usr-1")
        assert_nil result
      end

      test "reset password raises validation when email missing" do
        service = Admin::Users::ResetPassword.new(
          client: FakeClient.new(get_response: []),
          auth: FakeAuth.new(create_user_response: {})
        )

        assert_raises(ServiceErrors::Validation) do
          service.call(id: "usr-2")
        end
      end
    end
  end
end
