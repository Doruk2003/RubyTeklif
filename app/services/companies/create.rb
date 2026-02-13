module Companies
  class Create
    def initialize(client: nil, repository: nil)
      @repository = repository || Companies::Repository.new(client: client)
    end

    def call(form_payload:, actor_id:)
      form = Companies::UpsertForm.new(form_payload)
      validate_form!(form)

      payload = form.normalized_attributes
      created = @repository.create_with_audit_atomic(payload: payload, actor_id: actor_id)
      raise_from_response!(created, fallback: "Musteri olusturulamadi.")

      company_id = extract_id(created)
      raise ServiceErrors::System.new(user_message: "Kayit dogrulanamadi. Lutfen tekrar deneyin.") if company_id.blank?

      company_name = payload[:name].to_s.strip
      notice = company_name.present? ? "#{company_name} musterisi olusturuldu." : "Musteri olusturuldu."
      { id: company_id, notice: notice }
    end

    private

    def validate_form!(form)
      return if form.valid?

      raise ServiceErrors::Validation.new(user_message: form.errors.full_messages.join(", "))
    end

    def extract_id(response)
      return response.first["company_id"].to_s if response.is_a?(Array) && response.first.is_a?(Hash) && response.first["company_id"].present?
      return response.first["id"].to_s if response.is_a?(Array) && response.first.is_a?(Hash)
      return response["company_id"].to_s if response.is_a?(Hash) && response["company_id"].present?
      return response["id"].to_s if response.is_a?(Hash)

      nil
    end

    def raise_from_response!(response, fallback:)
      return unless response.is_a?(Hash) && (response["message"].present? || response["error"].present?)

      if duplicate_tax_number_error?(response)
        raise ServiceErrors::Validation.new(user_message: "Bu vergi numarasi zaten kayitli.")
      end

      if response["code"].to_s == "42501"
        raise ServiceErrors::Policy.new(user_message: "Bu islem icin yetkiniz yok.")
      end

      parts = [response["message"], response["details"], response["hint"], response["code"]].compact.reject(&:blank?)
      raise ServiceErrors::System.new(user_message: parts.presence&.join(" | ") || fallback)
    end

    def duplicate_tax_number_error?(response)
      return false unless response.is_a?(Hash) && response["code"].to_s == "23505"

      message = response["message"].to_s.downcase
      message.include?("companies_tax_number_idx") || message.include?("companies_user_tax_number_idx")
    end
  end
end
