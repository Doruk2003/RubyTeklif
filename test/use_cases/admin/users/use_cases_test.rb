require "test_helper"

module Admin
  module Users
    class UseCasesTest < ActiveSupport::TestCase
      class FakeCreate
        attr_reader :payload, :actor_id

        def call(form_payload:, actor_id:)
          @payload = form_payload
          @actor_id = actor_id
          "usr-2"
        end
      end

      class FakeUpdateRole
        attr_reader :id, :role, :actor_id

        def call(id:, role:, actor_id:)
          @id = id
          @role = role
          @actor_id = actor_id
          true
        end
      end

      class FakeSetActive
        attr_reader :id, :active, :actor_id

        def call(id:, active:, actor_id:)
          @id = id
          @active = active
          @actor_id = actor_id
          { action: active ? "users.enable" : "users.disable" }
        end
      end

      class FakeResetPassword
        attr_reader :id, :actor_id

        def call(id:, actor_id:)
          @id = id
          @actor_id = actor_id
          true
        end
      end

      test "create user use case delegates to create service" do
        fake = FakeCreate.new
        use_case = CreateUser.new(client: Object.new, create_service_factory: ->(_c) { fake })

        result = use_case.call(form_payload: { email: "x@example.com", role: Roles::MANAGER }, actor_id: "usr-1")

        assert_equal "usr-2", result
        assert_equal({ email: "x@example.com", role: Roles::MANAGER }, fake.payload)
        assert_equal "usr-1", fake.actor_id
      end

      test "update role use case delegates to update role service" do
        fake = FakeUpdateRole.new
        use_case = UpdateUserRole.new(client: Object.new, update_service_factory: ->(_c) { fake })

        assert use_case.call(id: "usr-2", role: Roles::VIEWER, actor_id: "usr-1")
        assert_equal "usr-2", fake.id
        assert_equal Roles::VIEWER, fake.role
        assert_equal "usr-1", fake.actor_id
      end

      test "set active use case delegates to set active service" do
        fake = FakeSetActive.new
        use_case = SetUserActive.new(client: Object.new, set_active_service_factory: ->(_c) { fake })

        result = use_case.call(id: "usr-2", active: false, actor_id: "usr-1")

        assert_equal "users.disable", result[:action]
        assert_equal "usr-2", fake.id
        assert_equal false, fake.active
        assert_equal "usr-1", fake.actor_id
      end

      test "reset password use case delegates to reset service" do
        fake = FakeResetPassword.new
        use_case = ResetUserPassword.new(client: Object.new, reset_service_factory: ->(_c) { fake })

        assert use_case.call(id: "usr-2", actor_id: "usr-1")
        assert_equal "usr-2", fake.id
        assert_equal "usr-1", fake.actor_id
      end
    end
  end
end
