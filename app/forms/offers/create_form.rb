require "date"
require "bigdecimal"

module Offers
  class CreateForm
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :company_id, :string
    attribute :offer_number, :string
    attribute :offer_date, :string
    attribute :status, :string
    attribute :items, default: []

    validates :company_id, presence: true
    validates :offer_number, presence: true, length: { maximum: 60 }
    validates :offer_date, presence: true
    validates :status, inclusion: { in: Offers::Status::ALLOWED }, allow_blank: true
    validate :offer_date_must_be_parseable
    validate :items_must_be_present
    validate :discount_rates_must_be_valid

    def normalized_attributes
      {
        company_id: company_id.to_s,
        offer_number: offer_number.to_s.strip,
        offer_date: offer_date.to_s,
        status: status.to_s.presence || "taslak",
        items: normalize_items(items)
      }
    end

    private

    def offer_date_must_be_parseable
      return if offer_date.blank?
      return if Date.iso8601(offer_date.to_s)

      errors.add(:offer_date, "gecersiz")
    rescue Date::Error
      errors.add(:offer_date, "gecersiz")
    end

    def items_must_be_present
      normalized = normalize_items(items)
      errors.add(:items, "en az bir kalem olmali") if normalized.empty?
    end

    def normalize_items(raw_items)
      Array(raw_items).map do |item|
        {
          product_id: item[:product_id].to_s,
          description: item[:description].to_s,
          quantity: item[:quantity],
          unit_price: item[:unit_price],
          discount_rate: item[:discount_rate]
        }
      end.reject { |i| i[:product_id].blank? }
    end

    def discount_rates_must_be_valid
      normalize_items(items).each_with_index do |item, index|
        value = item[:discount_rate].to_s
        value = "0" if value.blank?

        rate = BigDecimal(value)
        next if rate >= BigDecimal("0") && rate <= BigDecimal("100")

        errors.add(:items, "#{index + 1}. kalem icin iskonto orani 0-100 arasinda olmali")
      rescue ArgumentError
        errors.add(:items, "#{index + 1}. kalem icin iskonto orani gecersiz")
      end
    end
  end
end
