require "bigdecimal"

module Products
  class UpsertForm
    include ActiveModel::Model
    include ActiveModel::Attributes

    ALLOWED_TYPES = %w[product service demonte hizmet malzeme sistem_bileseni].freeze
    ALLOWED_UNITS = %w[adet m m2 kg lt saat paket].freeze
    ITEM_TYPE_OPTIONS = [
      ["Urun", "product"],
      ["Servis", "service"],
      ["Demonte", "demonte"],
      ["Hizmet", "hizmet"],
      ["Malzeme", "malzeme"],
      ["Sistem Bileseni", "sistem_bileseni"]
    ].freeze
    UNIT_OPTIONS = [
      ["Adet", "adet"],
      ["Metre", "m"],
      ["Metrekare", "m2"],
      ["Kilogram", "kg"],
      ["Litre", "lt"],
      ["Saat", "saat"],
      ["Paket", "paket"]
    ].freeze

    attribute :sku, :string
    attribute :name, :string
    attribute :description, :string
    attribute :barcode, :string
    attribute :gtip_code, :string
    attribute :price
    attribute :cost_price
    attribute :stock_quantity
    attribute :min_stock_level
    attribute :vat_rate
    attribute :item_type, :string
    attribute :category_id, :string
    attribute :brand_id, :string
    attribute :currency_id, :string
    attribute :unit, :string
    attribute :is_stock_item
    attribute :sale_price_vat_included
    attribute :cost_price_vat_included
    attribute :active

    validates :sku, length: { maximum: 64 }, format: { with: /\A[a-zA-Z0-9._-]+\z/ }, allow_blank: true
    validates :name, presence: true, length: { maximum: 150 }
    validates :description, length: { maximum: 2000 }, allow_blank: true
    validates :barcode, length: { maximum: 64 }, format: { with: /\A[a-zA-Z0-9._-]+\z/ }, allow_blank: true
    validates :gtip_code, length: { maximum: 50 }, allow_blank: true
    validates :item_type, inclusion: { in: ALLOWED_TYPES }
    validates :category_id, presence: true, format: { with: /\A[0-9a-fA-F-]{36}\z/ }
    validates :brand_id, format: { with: /\A[0-9a-fA-F-]{36}\z/ }, allow_blank: true
    validates :currency_id, format: { with: /\A[0-9a-fA-F-]{36}\z/ }, allow_blank: true
    validates :unit, inclusion: { in: ALLOWED_UNITS }
    validates :price, numericality: { greater_than_or_equal_to: 0 }
    validates :cost_price, numericality: { greater_than_or_equal_to: 0 }
    validates :stock_quantity, numericality: { greater_than_or_equal_to: 0 }
    validates :min_stock_level, numericality: { greater_than_or_equal_to: 0 }
    validates :vat_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

    def normalized_attributes
      vat = decimal_to_float(vat_rate)
      sale_gross = decimal_to_float(price)
      cost_gross = decimal_to_float(cost_price)
      stock_item = normalize_bool(is_stock_item)

      sale_vat_included = normalize_bool(sale_price_vat_included)
      cost_vat_included = normalize_bool(cost_price_vat_included)

      {
        sku: normalize_sku(sku),
        name: name.to_s.strip,
        description: normalize_nullable_text(description),
        barcode: normalize_barcode(barcode),
        gtip_code: normalize_gtip_code(gtip_code),
        price: sale_vat_included ? gross_to_net(sale_gross, vat) : sale_gross,
        cost_price: cost_vat_included ? gross_to_net(cost_gross, vat) : cost_gross,
        stock_quantity: stock_item ? decimal_to_float(stock_quantity) : 0.0,
        min_stock_level: stock_item ? decimal_to_float(min_stock_level) : 0.0,
        vat_rate: vat,
        item_type: item_type.to_s.downcase,
        category_id: category_id.to_s,
        brand_id: normalize_brand_id(brand_id),
        currency_id: normalize_currency_id(currency_id),
        unit: unit.to_s.downcase,
        is_stock_item: stock_item,
        sale_price_vat_included: sale_vat_included,
        cost_price_vat_included: cost_vat_included,
        active: normalize_active(active)
      }
    end

    private

    def decimal_to_float(value)
      BigDecimal(value.to_s).to_f
    rescue ArgumentError
      0.0
    end

    def gross_to_net(gross, vat_rate_value)
      rate = vat_rate_value.to_f
      return gross if rate <= 0

      gross / (1 + (rate / 100.0))
    end

    def normalize_sku(value)
      value.to_s.strip.upcase
    end

    def normalize_brand_id(value)
      cleaned = value.to_s.strip
      cleaned.presence
    end

    def normalize_currency_id(value)
      cleaned = value.to_s.strip
      cleaned.presence
    end

    def normalize_barcode(value)
      normalize_nullable_text(value)&.upcase
    end

    def normalize_gtip_code(value)
      normalize_nullable_text(value)&.upcase
    end

    def normalize_nullable_text(value)
      cleaned = value.to_s.strip
      cleaned.presence
    end

    def normalize_bool(value)
      value.to_s.in?(%w[1 true on])
    end

    def normalize_active(value)
      normalize_bool(value)
    end
  end
end
