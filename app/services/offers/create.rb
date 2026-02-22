module Offers
  class Create
    def initialize(repository:, totals: Offers::TotalsCalculator.new)
      @repository = repository
      @totals = totals
    end

    def call(payload:, user_id:)
      form = Offers::CreateForm.new(payload)
      validate_form!(form)
      normalized = form.normalized_attributes
      validate_offer_number_uniqueness!(offer_number: normalized[:offer_number])

      items = normalized.delete(:items)
      product_map = @repository.fetch_products(items.map { |i| i[:product_id] })
      built_items = Offers::ItemBuilder.new(product_map).build(items)
      raise ServiceErrors::Validation.new(user_message: "Kalemler gecersiz.") if built_items.empty?

      totals = @totals.call(built_items)
      offer_body = normalized.merge(
        status: Offers::Status.normalize(normalized[:status]),
        user_id: user_id,
        net_total: totals[:net_total],
        vat_total: totals[:vat_total],
        gross_total: totals[:gross_total]
      )

      created = @repository.create_offer_with_items(
        offer_body: offer_body,
        items: built_items,
        user_id: user_id
      )
      raise_from_response!(created, fallback: "Teklif olusturulamadi.")

      offer_id = extract_offer_id(created)
      raise ServiceErrors::System.new(user_message: "Teklif ID alinmadi.") if offer_id.blank?

      offer_id
    end

    private

    def validate_form!(form)
      return if form.valid?

      raise ServiceErrors::Validation.new(user_message: form.errors.full_messages.join(", "))
    end

    def raise_from_response!(response, fallback:)
      return unless response.is_a?(Hash) && (response["message"].present? || response["error"].present?)

      if response["code"].to_s == "23505"
        raise ServiceErrors::Validation.new(user_message: "Bu teklif numarasi zaten kayitli.")
      end

      if response["code"].to_s == "42501"
        raise ServiceErrors::Policy.new(user_message: "Bu islem icin yetkiniz yok.")
      end

      parts = [response["message"], response["details"], response["hint"], response["code"]].compact.reject(&:blank?)
      raise ServiceErrors::System.new(user_message: parts.presence&.join(" | ") || fallback)
    end

    def extract_offer_id(response)
      if response.is_a?(Array) && response.first.is_a?(Hash)
        row = response.first
        return row["offer_id"].to_s if row["offer_id"].present?
        return row["id"].to_s if row["id"].present?
      end
      return response["offer_id"].to_s if response.is_a?(Hash) && response["offer_id"].present?
      return response["id"].to_s if response.is_a?(Hash) && response["id"].present?
      return response.to_s if response.is_a?(String)

      nil
    end

    def validate_offer_number_uniqueness!(offer_number:)
      return unless @repository.offer_number_taken?(offer_number: offer_number)

      raise ServiceErrors::Validation.new(user_message: "Bu teklif numarasi zaten kayitli.")
    end
  end
end
