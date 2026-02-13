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
          return @get_response.call(_path) if @get_response.respond_to?(:call)

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
        client = FakeClient.new(
          patch_response: { "code" => "42501", "message" => "forbidden" },
          get_response: lambda { |path|
            if path.include?("id=eq.usr-2")
              [{ "id" => "usr-2", "role" => Roles::SALES, "active" => true }]
            else
              [{ "id" => "usr-1" }, { "id" => "usr-9" }]
            end
          }
        )
        service = Admin::Users::UpdateRole.new(client: client, audit_log: FakeAuditLog.new)

        assert_raises(ServiceErrors::Policy) do
          service.call(id: "usr-2", role: Roles::FINANCE, actor_id: "usr-1")
        end
      end

      test "set active works for disable" do
        client = FakeClient.new(
          patch_response: [],
          get_response: lambda { |path|
            if path.include?("id=eq.usr-2")
              [{ "id" => "usr-2", "role" => Roles::SALES, "active" => true }]
            else
              [{ "id" => "usr-1" }, { "id" => "usr-3" }]
            end
          }
        )
        service = Admin::Users::SetActive.new(client: client, audit_log: FakeAuditLog.new)

        result = service.call(id: "usr-2", active: false, actor_id: "usr-1")
        assert_equal "users.disable", result[:action]
      end

      test "set active blocks self disable" do
        service = Admin::Users::SetActive.new(client: FakeClient.new, audit_log: FakeAuditLog.new)

        assert_raises(ServiceErrors::Validation) do
          service.call(id: "usr-1", active: false, actor_id: "usr-1")
        end
      end

      test "set active blocks disabling last active admin" do
        client = FakeClient.new(
          patch_response: [],
          get_response: lambda { |path|
            if path.include?("id=eq.usr-1")
              [{ "id" => "usr-1", "role" => Roles::ADMIN, "active" => true }]
            else
              [{ "id" => "usr-1" }]
            end
          }
        )
        service = Admin::Users::SetActive.new(client: client, audit_log: FakeAuditLog.new)

        assert_raises(ServiceErrors::Validation) do
          service.call(id: "usr-1", active: false, actor_id: "usr-2")
        end
      end

      test "update role blocks demoting last active admin" do
        client = FakeClient.new(
          patch_response: [],
          get_response: lambda { |path|
            if path.include?("id=eq.usr-1")
              [{ "id" => "usr-1", "role" => Roles::ADMIN, "active" => true }]
            else
              [{ "id" => "usr-1" }]
            end
          }
        )
        service = Admin::Users::UpdateRole.new(client: client, audit_log: FakeAuditLog.new)

        assert_raises(ServiceErrors::Validation) do
          service.call(id: "usr-1", role: Roles::SALES, actor_id: "usr-2")
        end
      end

      test "update role validates role input" do
        service = Admin::Users::UpdateRole.new(client: FakeClient.new, audit_log: FakeAuditLog.new)

        assert_raises(ServiceErrors::Validation) do
          service.call(id: "usr-1", role: "owner", actor_id: "usr-2")
        end
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
