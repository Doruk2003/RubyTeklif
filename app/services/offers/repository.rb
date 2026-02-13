require "bigdecimal"

module Offers
  class Repository
    attr_reader :client

    def initialize(client:)
      @client = client
    end

    def fetch_products(ids)
      ids = Supabase::FilterValue.uuid_list(ids)
      return {} if ids.empty?

      encoded_ids = ids.join(",")
      data = @client.get("products?deleted_at=is.null&select=id,name,vat_rate&id=in.(#{encoded_ids})")
      return {} unless data.is_a?(Array)

      data.each_with_object({}) do |row, acc|
        acc[row["id"].to_s] = {
          name: row["name"].to_s,
          vat_rate: decimal(row["vat_rate"])
        }
      end
    end

    def create_offer_with_items(offer_body:, items:, user_id:)
      payload = {
        p_actor_id: user_id,
        p_company_id: offer_body[:company_id],
        p_offer_number: offer_body[:offer_number],
        p_offer_date: offer_body[:offer_date],
        p_status: offer_body[:status],
        p_net_total: offer_body[:net_total],
        p_vat_total: offer_body[:vat_total],
        p_gross_total: offer_body[:gross_total],
        p_items: items.map do |item|
          {
            product_id: item[:product_id],
            description: item[:description],
            quantity: item[:quantity].to_s,
            unit_price: item[:unit_price].to_s,
            discount_rate: item[:discount_rate].to_s,
            line_total: item[:line_total].to_s
          }
        end
      }

      @client.post("rpc/create_offer_with_items_atomic", body: payload, headers: { "Prefer" => "return=representation" })
    end

    private

    def decimal(value)
      return BigDecimal("0") if value.nil?

      BigDecimal(value.to_s)
    rescue ArgumentError
      BigDecimal("0")
    end
  end
end
