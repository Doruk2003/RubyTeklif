module Products
  class Update
    def initialize(client:)
      @client = client
    end

    def call(id:, form_payload:, actor_id:)
      form = Products::UpsertForm.new(form_payload)
      validate_form!(form)

      payload = form.normalized_attributes
      response = @client.post(
        "rpc/update_product_with_audit_atomic",
        body: {
          p_actor_id: actor_id,
          p_product_id: id,
          p_name: payload[:name],
          p_price: payload[:price],
          p_vat_rate: payload[:vat_rate],
          p_item_type: payload[:item_type],
          p_category_id: payload[:category_id],
          p_active: payload[:active]
        },
        headers: { "Prefer" => "return=representation" }
      )
      raise_from_response!(response, fallback: "Urun guncellenemedi.")

      product_id = extract_product_id(response) || id
      { id: product_id, payload: payload }
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

    def extract_product_id(response)
      if response.is_a?(Array) && response.first.is_a?(Hash)
        row = response.first
        return row["product_id"].to_s if row["product_id"].present?
        return row["id"].to_s if row["id"].present?
      end
      return response["product_id"].to_s if response.is_a?(Hash) && response["product_id"].present?
      return response["id"].to_s if response.is_a?(Hash) && response["id"].present?
      return response.to_s if response.is_a?(String)

      nil
    end
  end
end
