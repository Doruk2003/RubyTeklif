require "test_helper"

module Categories
  class UseCasesTest < ActiveSupport::TestCase
    class FakeCreate
      attr_reader :payload, :actor_id

      def call(form_payload:, actor_id:)
        @payload = form_payload
        @actor_id = actor_id
        "cat-1"
      end
    end

    class FakeUpdate
      attr_reader :id, :payload, :actor_id

      def call(id:, form_payload:, actor_id:)
        @id = id
        @payload = form_payload
        @actor_id = actor_id
        { id: id, payload: form_payload }
      end
    end

    class FakeDestroy
      attr_reader :id, :actor_id

      def call(id:, actor_id:)
        @id = id
        @actor_id = actor_id
        true
      end
    end

    class FakeRestore
      attr_reader :id, :actor_id

      def call(id:, actor_id:)
        @id = id
        @actor_id = actor_id
        true
      end
    end

    test "create use case delegates to create service" do
      fake = FakeCreate.new
      use_case = Categories::CreateCategory.new(client: Object.new, create_service_factory: ->(_c) { fake })

      id = use_case.call(form_payload: { code: "service", name: "Service" }, actor_id: "usr-1")

      assert_equal "cat-1", id
      assert_equal({ code: "service", name: "Service" }, fake.payload)
      assert_equal "usr-1", fake.actor_id
    end

    test "update use case delegates to update service" do
      fake = FakeUpdate.new
      use_case = Categories::UpdateCategory.new(client: Object.new, update_service_factory: ->(_c) { fake })

      result = use_case.call(id: "cat-1", form_payload: { name: "Updated" }, actor_id: "usr-1")

      assert_equal "cat-1", result[:id]
      assert_equal "cat-1", fake.id
      assert_equal "usr-1", fake.actor_id
    end

    test "archive use case delegates to destroy service" do
      fake = FakeDestroy.new
      use_case = Categories::ArchiveCategory.new(client: Object.new, destroy_service_factory: ->(_c) { fake })

      assert use_case.call(id: "cat-1", actor_id: "usr-1")
      assert_equal "cat-1", fake.id
      assert_equal "usr-1", fake.actor_id
    end

    test "restore use case delegates to restore service" do
      fake = FakeRestore.new
      use_case = Categories::RestoreCategory.new(client: Object.new, restore_service_factory: ->(_c) { fake })

      assert use_case.call(id: "cat-1", actor_id: "usr-1")
      assert_equal "cat-1", fake.id
      assert_equal "usr-1", fake.actor_id
    end
  end
end
