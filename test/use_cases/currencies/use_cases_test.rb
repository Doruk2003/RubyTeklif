require "test_helper"

module Currencies
  class UseCasesTest < ActiveSupport::TestCase
    class FakeCreate
      attr_reader :payload, :actor_id

      def call(form_payload:, actor_id:)
        @payload = form_payload
        @actor_id = actor_id
        "cur-1"
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
      use_case = Currencies::CreateCurrency.new(client: Object.new, create_service_factory: ->(_c) { fake })

      id = use_case.call(form_payload: { code: "USD" }, actor_id: "usr-1")

      assert_equal "cur-1", id
      assert_equal({ code: "USD" }, fake.payload)
      assert_equal "usr-1", fake.actor_id
    end

    test "update use case delegates to update service" do
      fake = FakeUpdate.new
      use_case = Currencies::UpdateCurrency.new(client: Object.new, update_service_factory: ->(_c) { fake })

      result = use_case.call(id: "cur-1", form_payload: { code: "EUR" }, actor_id: "usr-1")

      assert_equal({ code: "EUR" }, result)
      assert_equal "cur-1", fake.id
      assert_equal "usr-1", fake.actor_id
    end

    test "archive use case delegates to destroy service" do
      fake = FakeDestroy.new
      use_case = Currencies::ArchiveCurrency.new(client: Object.new, destroy_service_factory: ->(_c) { fake })

      assert use_case.call(id: "cur-1", actor_id: "usr-1")
      assert_equal "cur-1", fake.id
      assert_equal "usr-1", fake.actor_id
    end
  end
end
