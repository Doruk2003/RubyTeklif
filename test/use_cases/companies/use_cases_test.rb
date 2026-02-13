require "test_helper"

module Companies
  class UseCasesTest < ActiveSupport::TestCase
    class FakeCreate
      attr_reader :payload, :actor_id

      def call(form_payload:, actor_id:)
        @payload = form_payload
        @actor_id = actor_id
        { id: "cmp-1", notice: "ok" }
      end
    end

    class FakeUpdate
      attr_reader :id, :payload, :actor_id

      def call(id:, form_payload:, actor_id:)
        @id = id
        @payload = form_payload
        @actor_id = actor_id
        form_payload
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

    test "create use case delegates to create service" do
      fake = FakeCreate.new
      use_case = Companies::CreateCompany.new(client: Object.new, create_service_factory: ->(_c) { fake })

      result = use_case.call(form_payload: { name: "Acme" }, actor_id: "usr-1")

      assert_equal "cmp-1", result[:id]
      assert_equal({ name: "Acme" }, fake.payload)
      assert_equal "usr-1", fake.actor_id
    end

    test "update use case delegates to update service" do
      fake = FakeUpdate.new
      use_case = Companies::UpdateCompany.new(client: Object.new, update_service_factory: ->(_c) { fake })

      result = use_case.call(id: "cmp-1", form_payload: { name: "New" }, actor_id: "usr-1")

      assert_equal({ name: "New" }, result)
      assert_equal "cmp-1", fake.id
      assert_equal "usr-1", fake.actor_id
    end

    test "archive use case delegates to destroy service" do
      fake = FakeDestroy.new
      use_case = Companies::ArchiveCompany.new(client: Object.new, destroy_service_factory: ->(_c) { fake })

      assert use_case.call(id: "cmp-1", actor_id: "usr-1")
      assert_equal "cmp-1", fake.id
      assert_equal "usr-1", fake.actor_id
    end
  end
end
