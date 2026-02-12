require "bigdecimal"

module Offers
  class TotalsCalculator
    def call(items)
      net_total = decimal(0)
      vat_total = decimal(0)

      items.each do |item|
        net_total += item[:line_total]
        vat_total += item[:line_total] * item[:vat_rate] / decimal(100)
      end

      gross_total = net_total + vat_total

      {
        net_total: net_total,
        vat_total: vat_total,
        gross_total: gross_total
      }
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
