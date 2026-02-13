require "test_helper"

module Offers
  class CreateTest < ActiveSupport::TestCase
    class FakeRepository
      attr_reader :offer_payload, :items_payload

      def initialize(create_offer_response:, create_items_response: [])
        @create_offer_response = create_offer_response
        @create_items_response = create_items_response
      end

      def client
        @client ||= Object.new
      end

      def fetch_products(ids)
        Array(ids).each_with_object({}) do |id, acc|
          acc[id.to_s] = { name: "Kalem #{id}", vat_rate: BigDecimal("20") }
        end
      end

      def create_offer(payload)
        @offer_payload = payload
        @create_offer_response
      end

      def create_items(offer_id, items, user_id:)
        @items_payload = { offer_id: offer_id, items: items, user_id: user_id }
        @create_items_response
      end
    end

    class FakeAuditLog
      attr_reader :payload

      def log(**kwargs)
        @payload = kwargs
      end
    end

    test "creates offer and logs audit record" do
      repository = FakeRepository.new(create_offer_response: [{ "id" => "off-1" }])
      audit_log = FakeAuditLog.new
      service = Offers::Create.new(repository: repository, audit_log: audit_log)

      offer_id = service.call(
        payload: {
          company_id: "cmp-1",
          offer_number: "TK-100",
          offer_date: "2026-02-13",
          status: "taslak",
          items: [{ product_id: "prd-1", description: "", quantity: "2", unit_price: "10", discount_rate: "0" }]
        },
        user_id: "usr-1"
      )

      assert_equal "off-1", offer_id
      assert_equal "usr-1", repository.offer_payload[:user_id]
      assert_equal "offers.create", audit_log.payload[:action]
      assert_equal "offer", audit_log.payload[:target_type]
      assert_equal "TK-100", audit_log.payload[:metadata][:offer_number]
      assert_equal BigDecimal("0"), repository.items_payload[:items][0][:discount_rate]
    end

    test "raises validation error when items are empty" do
      repository = FakeRepository.new(create_offer_response: [{ "id" => "off-1" }])
      service = Offers::Create.new(repository: repository, audit_log: FakeAuditLog.new)

      assert_raises(ServiceErrors::Validation) do
        service.call(
          payload: {
            company_id: "cmp-1",
            offer_number: "TK-100",
            offer_date: "2026-02-13",
            status: "taslak",
            items: []
          },
          user_id: "usr-1"
        )
      end
    end

    test "raises policy error when repository returns forbidden" do
      repository = FakeRepository.new(create_offer_response: { "code" => "42501", "message" => "forbidden" })
      service = Offers::Create.new(repository: repository, audit_log: FakeAuditLog.new)

      assert_raises(ServiceErrors::Policy) do
        service.call(
          payload: {
            company_id: "cmp-1",
            offer_number: "TK-100",
            offer_date: "2026-02-13",
            status: "taslak",
            items: [{ product_id: "prd-1", description: "", quantity: "2", unit_price: "10", discount_rate: "0" }]
          },
          user_id: "usr-1"
        )
      end
    end

    test "supports multiple items in one offer" do
      repository = FakeRepository.new(create_offer_response: [{ "id" => "off-9" }])
      service = Offers::Create.new(repository: repository, audit_log: FakeAuditLog.new)

      offer_id = service.call(
        payload: {
          company_id: "cmp-1",
          offer_number: "TK-900",
          offer_date: "2026-02-13",
          status: "taslak",
            items: [
            { product_id: "prd-1", description: "", quantity: "2", unit_price: "10", discount_rate: "10" },
            { product_id: "prd-2", description: "Ek Kalem", quantity: "1", unit_price: "25", discount_rate: "0" }
          ]
        },
        user_id: "usr-1"
      )

      assert_equal "off-9", offer_id
      assert_equal 2, repository.items_payload[:items].size
      assert_equal "prd-1", repository.items_payload[:items][0][:product_id]
      assert_equal "prd-2", repository.items_payload[:items][1][:product_id]
      assert_equal BigDecimal("18"), repository.items_payload[:items][0][:line_total]
    end

    test "raises validation error when discount rate is invalid" do
      repository = FakeRepository.new(create_offer_response: [{ "id" => "off-1" }])
      service = Offers::Create.new(repository: repository, audit_log: FakeAuditLog.new)

      assert_raises(ServiceErrors::Validation) do
        service.call(
          payload: {
            company_id: "cmp-1",
            offer_number: "TK-101",
            offer_date: "2026-02-13",
            status: "taslak",
            items: [{ product_id: "prd-1", description: "", quantity: "1", unit_price: "100", discount_rate: "120" }]
          },
          user_id: "usr-1"
        )
      end
    end
  end
end
