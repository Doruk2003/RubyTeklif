require "test_helper"

module Offers
  class CreateOfferTest < ActiveSupport::TestCase
    class FakeService
      attr_reader :received_payload, :received_user_id

      def call(payload:, user_id:)
        @received_payload = payload
        @received_user_id = user_id
        "off-42"
      end
    end

    test "delegates to offers create service" do
      fake_service = FakeService.new
      payload = {
        company_id: "cmp-1",
        offer_number: "TK-42",
        offer_date: "2026-02-14",
        status: "taslak",
        items: [{ product_id: "prd-1", quantity: "1", unit_price: "100", discount_rate: "0" }]
      }

      use_case = Offers::CreateOffer.new(
        client: Object.new,
        repository_factory: ->(_client) { Object.new },
        create_service_factory: ->(_repository, _totals) { fake_service }
      )

      offer_id = use_case.call(payload: payload, user_id: "usr-1")

      assert_equal "off-42", offer_id
      assert_equal payload, fake_service.received_payload
      assert_equal "usr-1", fake_service.received_user_id
    end
  end
end
