require "test_helper"

module Products
  class UpdateProductTest < ActiveSupport::TestCase
    class FakeService
      attr_reader :received_id, :received_payload, :received_actor_id

      def call(id:, form_payload:, actor_id:)
        @received_id = id
        @received_payload = form_payload
        @received_actor_id = actor_id
        { id: id, payload: form_payload }
      end
    end

    test "delegates to products update service" do
      fake_service = FakeService.new
      payload = {
        name: "Urun",
        price: "12",
        vat_rate: "20",
        item_type: "product",
        category_id: "11111111-1111-1111-1111-111111111111",
        active: "1"
      }

      use_case = Products::UpdateProduct.new(
        client: Object.new,
        update_service_factory: ->(_client) { fake_service }
      )

      result = use_case.call(id: "prd-1", form_payload: payload, actor_id: "usr-1")

      assert_equal "prd-1", result[:id]
      assert_equal "prd-1", fake_service.received_id
      assert_equal payload, fake_service.received_payload
      assert_equal "usr-1", fake_service.received_actor_id
    end
  end
end
