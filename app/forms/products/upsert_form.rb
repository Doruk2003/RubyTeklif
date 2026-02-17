require "bigdecimal"

module Products
  class UpsertForm
    include ActiveModel::Model
    include ActiveModel::Attributes

    ALLOWED_TYPES = %w[product service demonte hizmet malzeme sistem_bileseni].freeze

    attribute :name, :string
    attribute :price
    attribute :vat_rate
    attribute :item_type, :string
    attribute :category_id, :string
    attribute :active

    validates :name, presence: true, length: { maximum: 150 }
    validates :item_type, inclusion: { in: ALLOWED_TYPES }
    validates :category_id, presence: true, format: { with: /\A[0-9a-fA-F-]{36}\z/ }
    validates :price, numericality: { greater_than_or_equal_to: 0 }
    validates :vat_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

    def normalized_attributes
      {
        name: name.to_s.strip,
        price: decimal_to_float(price),
        vat_rate: decimal_to_float(vat_rate),
        item_type: item_type.to_s.downcase,
        category_id: category_id.to_s,
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
