require "test_helper"

module Products
  class CreateProductTest < ActiveSupport::TestCase
    class FakeService
      attr_reader :received_payload, :received_actor_id

      def call(form_payload:, actor_id:)
        @received_payload = form_payload
        @received_actor_id = actor_id
        "prd-42"
      end
    end

    test "delegates to products create service" do
      fake_service = FakeService.new
      payload = {
        name: "Urun",
        price: "10",
        vat_rate: "20",
        item_type: "product",
        category_id: "11111111-1111-1111-1111-111111111111",
        active: "1"
      }

      use_case = Products::CreateProduct.new(
        client: Object.new,
        create_service_factory: ->(_client) { fake_service }
      )

      product_id = use_case.call(form_payload: payload, actor_id: "usr-1")

      assert_equal "prd-42", product_id
      assert_equal payload, fake_service.received_payload
      assert_equal "usr-1", fake_service.received_actor_id
    end
  end
end
