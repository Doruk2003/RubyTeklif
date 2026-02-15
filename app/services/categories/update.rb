module Categories
  class Update
    def initialize(client: nil, repository: nil)
      @repository = repository || Categories::Repository.new(client: client)
    end

    def call(id:, form_payload:, actor_id:)
      form = Categories::UpsertForm.new(form_payload)
      validate_form!(form)

      payload = form.normalized_attributes
      updated = @repository.update_with_audit_atomic(category_id: id, payload: payload, actor_id: actor_id)
      raise_from_response!(updated, fallback: "Kategori guncellenemedi.")

      category_id = extract_id(updated) || id
      { id: category_id, payload: payload }
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
      return response.first["category_id"].to_s if response.is_a?(Array) && response.first.is_a?(Hash) && response.first["category_id"].present?
      return response.first["id"].to_s if response.is_a?(Array) && response.first.is_a?(Hash)
      return response["category_id"].to_s if response.is_a?(Hash) && response["category_id"].present?
      return response["id"].to_s if response.is_a?(Hash)

      nil
    end
  end
end
