module Offers
  class Create
    def initialize(repository: Offers::Repository.new, totals: Offers::TotalsCalculator.new)
      @repository = repository
      @totals = totals
    end

    def call(payload:, user_id:)
      items = payload.delete(:items)
      product_map = @repository.fetch_products(items.map { |i| i[:product_id] })
      built_items = Offers::ItemBuilder.new(product_map).build(items)
      totals = @totals.call(built_items)

      offer_body = payload.merge(
        status: Offers::Status.normalize(payload[:status]),
        user_id: user_id,
        net_total: totals[:net_total],
        vat_total: totals[:vat_total],
        gross_total: totals[:gross_total]
      )

      created = @repository.create_offer(offer_body)
      offer_id = extract_id(created)
      raise "Teklif ID alinmadi." if offer_id.blank?

      @repository.create_items(offer_id, built_items, user_id: user_id)
      offer_id
    end

    private

    def extract_id(response)
      return response.first["id"].to_s if response.is_a?(Array) && response.first.is_a?(Hash)
      return response["id"].to_s if response.is_a?(Hash)

      nil
    end
  end
end
