require "bigdecimal"

module Currencies
  class UpsertForm
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :code, :string
    attribute :name, :string
    attribute :symbol, :string
    attribute :rate_to_try
    attribute :active

    validates :code, presence: true, length: { in: 2..10 }
    validates :name, presence: true, length: { maximum: 100 }
    validates :symbol, length: { maximum: 10 }, allow_blank: true
    validates :rate_to_try, numericality: { greater_than: 0 }

    def normalized_attributes
      {
        code: code.to_s.upcase.strip,
        name: name.to_s.strip,
        symbol: symbol.to_s.strip,
        rate_to_try: decimal_to_float(rate_to_try),
        active: normalize_active(active)
      }
    end

    private

    def decimal_to_float(value)
      BigDecimal(value.to_s).to_f
    rescue ArgumentError
      0.0
    end

    def normalize_active(value)
      value.to_s.in?(%w[1 true on])
    end
  end
end

