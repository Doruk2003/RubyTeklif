module Currencies
  class Update
    def initialize(client: nil, repository: nil)
      @repository = repository || Currencies::Repository.new(client: client)
    end

    def call(id:, form_payload:, actor_id:)
      form = Currencies::UpsertForm.new(form_payload)
      validate_form!(form)

      payload = form.normalized_attributes
      validate_code_uniqueness!(currency_id: id, code: payload[:code])
      updated = @repository.update_with_audit_atomic(currency_id: id, payload: payload, actor_id: actor_id)
      raise_from_response!(updated, fallback: "Kur guncellenemedi.")

      payload
    end

    private

    def validate_form!(form)
      return if form.valid?

      raise ServiceErrors::Validation.new(user_message: form.errors.full_messages.join(", "))
    end

    def raise_from_response!(response, fallback:)
      return unless response.is_a?(Hash) && (response["message"].present? || response["error"].present?)

      if response["code"].to_s == "23505"
        raise ServiceErrors::Validation.new(user_message: "Bu kur kodu zaten kayitli.")
      end

      if response["code"].to_s == "42501"
        raise ServiceErrors::Policy.new(user_message: "Bu islem icin yetkiniz yok.")
      end

      parts = [response["message"], response["details"], response["hint"], response["code"]].compact.reject(&:blank?)
      raise ServiceErrors::System.new(user_message: parts.presence&.join(" | ") || fallback)
    end

    def validate_code_uniqueness!(currency_id:, code:)
      return unless @repository.code_taken?(code: code, exclude_currency_id: currency_id)

      raise ServiceErrors::Validation.new(user_message: "Bu kur kodu zaten kayitli.")
    end
  end
end
