module Products
  class Create
    def initialize(client: nil, repository: nil)
      @repository = repository || Products::Repository.new(client: client)
    end

    def call(form_payload:, actor_id:)
      form = Products::UpsertForm.new(form_payload)
      validate_form!(form)

      payload = form.normalized_attributes
      response = @repository.create_with_audit_atomic(payload: payload, actor_id: actor_id)
      raise_from_response!(response, fallback: "Urun olusturulamadi.")

      product_id = extract_product_id(response)
      raise ServiceErrors::System.new(user_message: "Urun ID alinamadi.") if product_id.blank?

      product_id
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
