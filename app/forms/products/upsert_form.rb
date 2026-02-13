require "bigdecimal"

module Products
  class UpsertForm
    include ActiveModel::Model
    include ActiveModel::Attributes

    ALLOWED_TYPES = %w[product demonte service].freeze

    attribute :company_id, :string
    attribute :name, :string
    attribute :price
    attribute :vat_rate
    attribute :item_type, :string
    attribute :active

    validates :company_id, presence: true
    validates :name, presence: true, length: { maximum: 150 }
    validates :item_type, inclusion: { in: ALLOWED_TYPES }
    validates :price, numericality: { greater_than_or_equal_to: 0 }
    validates :vat_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

    def normalized_attributes
      {
        company_id: company_id.to_s,
        name: name.to_s.strip,
        price: decimal_to_float(price),
        vat_rate: decimal_to_float(vat_rate),
        item_type: item_type.to_s.downcase,
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
