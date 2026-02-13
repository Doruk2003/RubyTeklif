module Companies
  class Update
    def initialize(client:, audit_log: AuditLog.new(client: client))
      @client = client
      @audit_log = audit_log
    end

    def call(id:, form_payload:, actor_id:)
      form = Companies::UpsertForm.new(form_payload)
      validate_form!(form)

      payload = form.normalized_attributes
      updated = @client.patch("companies?id=eq.#{id}", body: payload, headers: { "Prefer" => "return=representation" })

      raise_from_response!(updated, fallback: "Musteri guncellenemedi.")
      raise ServiceErrors::System.new(user_message: "Musteri bulunamadi veya guncellenemedi.") if updated.is_a?(Array) && updated.empty?

      @audit_log.log(
        action: "companies.update",
        actor_id: actor_id,
        target_id: id,
        target_type: "company",
        metadata: { name: payload[:name].to_s }
      )

      payload
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
  end
end
