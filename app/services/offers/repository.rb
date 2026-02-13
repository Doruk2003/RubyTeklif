require "bigdecimal"

module Offers
  class Repository
    attr_reader :client

    def initialize(client:)
      @client = client
    end

    def fetch_products(ids)
      ids = Array(ids).compact.uniq
      return {} if ids.empty?

      encoded_ids = ids.join(",")
      data = @client.get("products?select=id,name,vat_rate&id=in.(#{encoded_ids})")
      return {} unless data.is_a?(Array)

      data.each_with_object({}) do |row, acc|
        acc[row["id"].to_s] = {
          name: row["name"].to_s,
          vat_rate: decimal(row["vat_rate"])
        }
      end
    end

    def create_offer(payload)
      @client.post("offers", body: payload, headers: { "Prefer" => "return=representation" })
    end

    def create_items(offer_id, items, user_id:)
      return [] if items.empty?

      payload = items.map do |item|
        {
          user_id: user_id,
          offer_id: offer_id,
          product_id: item[:product_id],
          description: item[:description],
          quantity: item[:quantity],
          unit_price: item[:unit_price],
          line_total: item[:line_total]
        }
      end

      @client.post("offer_items", body: payload, headers: { "Prefer" => "return=minimal" })
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
