require "test_helper"

module Admin
  module Users
    class ServicesTest < ActiveSupport::TestCase
      class FakeClient
        attr_reader :last_post_path, :last_post_body

        def initialize(post_response: nil, patch_response: nil, get_response: nil)
          @post_response = post_response
          @patch_response = patch_response
          @get_response = get_response
        end

        def post(_path, body:, headers:)
          @last_post_path = _path
          @last_post_body = body
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
        attr_reader :deleted_user_id

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

        def delete_user(user_id:)
          @deleted_user_id = user_id
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
        client = FakeClient.new(post_response: [], get_response: [])
        auth = FakeAuth.new(create_user_response: { "id" => "usr-2" })
        audit = FakeAuditLog.new

        user_id = Admin::Users::Create.new(client: client, auth: auth, audit_log: audit).call(
          form_payload: { email: "test@example.com", password: "Password12", role: Roles::OPERATOR },
          actor_id: "usr-1"
        )

        assert_equal "usr-2", user_id
        assert_equal "users.create", audit.payload[:action]
      end

      test "create user blocks duplicate email before auth call" do
        client = FakeClient.new(post_response: [], get_response: [{ "id" => "usr-existing" }])
        auth = FakeAuth.new(create_user_response: { "id" => "usr-2" })
        service = Admin::Users::Create.new(client: client, auth: auth, audit_log: FakeAuditLog.new)

        assert_raises(ServiceErrors::Validation) do
          service.call(
            form_payload: { email: "test@example.com", password: "Password12", role: Roles::OPERATOR },
            actor_id: "usr-1"
          )
        end

        assert_nil client.last_post_path
      end

      test "create user rejects legacy roles" do
        service = Admin::Users::Create.new(
          client: FakeClient.new(post_response: []),
          auth: FakeAuth.new(create_user_response: { "id" => "usr-2" }),
          audit_log: FakeAuditLog.new
        )

        assert_raises(ServiceErrors::Validation) do
          service.call(
            form_payload: { email: "legacy@example.com", password: "Password12", role: Roles::SALES },
            actor_id: "usr-1"
          )
        end
      end

      test "create user cleans up auth user when profile insert fails" do
        client = FakeClient.new(post_response: { "message" => "insert failed" })
        auth = FakeAuth.new(create_user_response: { "id" => "usr-9" })

        assert_raises(ServiceErrors::System) do
          Admin::Users::Create.new(client: client, auth: auth, audit_log: FakeAuditLog.new).call(
            form_payload: { email: "rollback@example.com", password: "Password12", role: Roles::MANAGER },
            actor_id: "usr-1"
          )
        end

        assert_equal "usr-9", auth.deleted_user_id
      end

      test "update role raises policy error for forbidden response" do
        client = FakeClient.new(
          post_response: { "code" => "42501", "message" => "forbidden" },
          get_response: lambda { |path|
            if path.include?("id=eq.usr-2")
              [{ "id" => "usr-2", "role" => Roles::SALES, "active" => true }]
            else
              [{ "id" => "usr-1" }, { "id" => "usr-9" }]
            end
          }
        )
        service = Admin::Users::UpdateRole.new(client: client)

        assert_raises(ServiceErrors::Policy) do
          service.call(id: "usr-2", role: Roles::MANAGER, actor_id: "usr-1")
        end

        assert_equal "rpc/admin_update_user_role_with_audit_atomic", client.last_post_path
        assert_equal "usr-1", client.last_post_body[:p_actor_id]
        assert_equal "usr-2", client.last_post_body[:p_target_user_id]
        assert_equal Roles::MANAGER, client.last_post_body[:p_role]
      end

      test "set active works for disable" do
        client = FakeClient.new(
          post_response: [],
          get_response: lambda { |path|
            if path.include?("id=eq.usr-2")
              [{ "id" => "usr-2", "role" => Roles::SALES, "active" => true }]
            else
              [{ "id" => "usr-1" }, { "id" => "usr-3" }]
            end
          }
        )
        service = Admin::Users::SetActive.new(client: client)

        result = service.call(id: "usr-2", active: false, actor_id: "usr-1")
        assert_equal "users.disable", result[:action]
        assert_equal "rpc/admin_set_user_active_with_audit_atomic", client.last_post_path
        assert_equal false, client.last_post_body[:p_active]
      end

      test "set active blocks self disable" do
        service = Admin::Users::SetActive.new(client: FakeClient.new)

        assert_raises(ServiceErrors::Validation) do
          service.call(id: "usr-1", active: false, actor_id: "usr-1")
        end
      end

      test "set active blocks disabling last active admin" do
        client = FakeClient.new(
          post_response: [],
          get_response: lambda { |path|
            if path.include?("id=eq.usr-1")
              [{ "id" => "usr-1", "role" => Roles::ADMIN, "active" => true }]
            else
              [{ "id" => "usr-1" }]
            end
          }
        )
        service = Admin::Users::SetActive.new(client: client)

        assert_raises(ServiceErrors::Validation) do
          service.call(id: "usr-1", active: false, actor_id: "usr-2")
        end
      end

      test "update role blocks demoting last active admin" do
        client = FakeClient.new(
          post_response: [],
          get_response: lambda { |path|
            if path.include?("id=eq.usr-1")
              [{ "id" => "usr-1", "role" => Roles::ADMIN, "active" => true }]
            else
              [{ "id" => "usr-1" }]
            end
          }
        )
        service = Admin::Users::UpdateRole.new(client: client)

        assert_raises(ServiceErrors::Validation) do
          service.call(id: "usr-1", role: Roles::MANAGER, actor_id: "usr-2")
        end
      end

      test "update role validates role input" do
        service = Admin::Users::UpdateRole.new(client: FakeClient.new)

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
          service.call(id: "usr-2", actor_id: "usr-1")
        end
      end

      test "reset password logs audit action" do
        audit = FakeAuditLog.new
        service = Admin::Users::ResetPassword.new(
          client: FakeClient.new(get_response: [{ "email" => "user@example.com" }]),
          auth: FakeAuth.new(create_user_response: {}),
          audit_log: audit
        )

        service.call(id: "usr-2", actor_id: "usr-1")
        assert_equal "users.reset_password", audit.payload[:action]
        assert_equal "usr-1", audit.payload[:actor_id]
        assert_equal "usr-2", audit.payload[:target_id]
      end
    end
  end
end
