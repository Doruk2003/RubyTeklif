require "bigdecimal"

module Offers
  class ItemBuilder
    def initialize(product_map)
      @product_map = product_map
    end

    def build(raw_items)
      normalize(raw_items).map { |item| enrich(item) }
    end

    private

    def normalize(raw_items)
      Array(raw_items).map do |item|
        {
          product_id: item[:product_id].to_s,
          description: item[:description].to_s,
          quantity: decimal(item[:quantity]),
          unit_price: decimal(item[:unit_price]),
          discount_rate: normalize_discount_rate(item[:discount_rate])
        }
      end.reject { |i| i[:product_id].empty? }
    end

    def enrich(item)
      product = @product_map[item[:product_id]] || {}
      quantity = item[:quantity]
      unit_price = item[:unit_price]
      discount_rate = item[:discount_rate]
      gross_line_total = quantity * unit_price
      discount_amount = gross_line_total * discount_rate / decimal(100)
      line_total = gross_line_total - discount_amount

      {
        product_id: item[:product_id],
        description: item[:description].presence || product[:name].to_s,
        quantity: quantity,
        unit_price: unit_price,
        discount_rate: discount_rate,
        line_total: line_total,
        vat_rate: product[:vat_rate] || decimal(0)
      }
    end

    def normalize_discount_rate(value)
      rate = decimal(value.presence || 0)
      return decimal(0) if rate.negative?
      return decimal(100) if rate > decimal(100)

      rate
    end

    def decimal(value)
      return BigDecimal("0") if value.nil?

      BigDecimal(value.to_s)
    rescue ArgumentError
      BigDecimal("0")
    end
  end
end
