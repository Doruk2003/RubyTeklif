module Offers
  class Create
    def initialize(repository:, totals: Offers::TotalsCalculator.new, audit_log: AuditLog.new(client: repository.client))
      @repository = repository
      @totals = totals
      @audit_log = audit_log
    end

    def call(payload:, user_id:)
      form = Offers::CreateForm.new(payload)
      validate_form!(form)
      normalized = form.normalized_attributes

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

      created = @repository.create_offer(offer_body)
      raise_from_response!(created, fallback: "Teklif olusturulamadi.")

      offer_id = extract_id(created)
      raise ServiceErrors::System.new(user_message: "Teklif ID alinmadi.") if offer_id.blank?

      items_response = @repository.create_items(offer_id, built_items, user_id: user_id)
      raise_from_response!(items_response, fallback: "Teklif kalemleri kaydedilemedi.")

      @audit_log.log(
        action: "offers.create",
        actor_id: user_id,
        target_id: offer_id,
        target_type: "offer",
        metadata: { offer_number: offer_body[:offer_number].to_s }
      )

      offer_id
    end

    private

    def validate_form!(form)
      return if form.valid?

      raise ServiceErrors::Validation.new(user_message: form.errors.full_messages.join(", "))
    end

    def raise_from_response!(response, fallback:)
      return unless response.is_a?(Hash) && (response["message"].present? || response["error"].present?)

      if response["code"].to_s == "42501"
        raise ServiceErrors::Policy.new(user_message: "Bu islem icin yetkiniz yok.")
      end

      parts = [response["message"], response["details"], response["hint"], response["code"]].compact.reject(&:blank?)
      raise ServiceErrors::System.new(user_message: parts.presence&.join(" | ") || fallback)
    end

    def extract_id(response)
      return response.first["id"].to_s if response.is_a?(Array) && response.first.is_a?(Hash)
      return response["id"].to_s if response.is_a?(Hash)

      nil
    end
  end
end
