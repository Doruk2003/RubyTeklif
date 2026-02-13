module Products
  class Update
    def initialize(client:, audit_log: AuditLog.new(client: client))
      @client = client
      @audit_log = audit_log
    end

    def call(id:, form_payload:, actor_id:)
      form = Products::UpsertForm.new(form_payload)
      validate_form!(form)

      payload = form.normalized_attributes
      updated = @client.patch("products?id=eq.#{id}", body: payload, headers: { "Prefer" => "return=representation" })
      raise_from_response!(updated, fallback: "Urun guncellenemedi.")

      product_id = extract_id(updated) || id

      @audit_log.log(
        action: "products.update",
        actor_id: actor_id,
        target_id: product_id,
        target_type: "product",
        metadata: { name: payload[:name].to_s }
      )

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

    def extract_id(response)
      return response.first["id"].to_s if response.is_a?(Array) && response.first.is_a?(Hash)
      return response["id"].to_s if response.is_a?(Hash)

      nil
    end
  end
end
