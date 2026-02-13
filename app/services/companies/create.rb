module Companies
  class Create
    def initialize(client:, audit_log: AuditLog.new(client: client))
      @client = client
      @audit_log = audit_log
    end

    def call(form_payload:, actor_id:)
      form = Companies::UpsertForm.new(form_payload)
      validate_form!(form)

      payload = form.normalized_attributes.merge(user_id: actor_id)
      created = @client.post("companies", body: payload, headers: { "Prefer" => "return=representation" })
      raise_from_response!(created, fallback: "Musteri olusturulamadi.")

      company_id = extract_id(created)
      company_id = find_company_id_by_tax_number_for_user(payload[:tax_number], payload[:user_id]) if company_id.blank?
      raise ServiceErrors::System.new(user_message: "Kayit dogrulanamadi. Lutfen tekrar deneyin.") unless company_exists?(company_id)

      company_name = payload[:name].to_s.strip
      @audit_log.log(
        action: "companies.create",
        actor_id: actor_id,
        target_id: company_id,
        target_type: "company",
        metadata: { name: company_name }
      )

      notice = company_name.present? ? "#{company_name} musterisi olusturuldu." : "Musteri olusturuldu."
      { id: company_id, notice: notice }
    end

    private

    def validate_form!(form)
      return if form.valid?

      raise ServiceErrors::Validation.new(user_message: form.errors.full_messages.join(", "))
    end

    def extract_id(response)
      return response.first["id"].to_s if response.is_a?(Array) && response.first.is_a?(Hash)
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

    def company_exists?(company_id)
      return false if company_id.blank?

      data = @client.get("companies?id=eq.#{company_id}&select=id&limit=1")
      data.is_a?(Array) && data.first.is_a?(Hash) && data.first["id"].present?
    rescue StandardError
      false
    end

    def find_company_id_by_tax_number_for_user(tax_number, user_id)
      return nil if tax_number.blank? || user_id.blank?

      data = @client.get("companies?user_id=eq.#{user_id}&tax_number=eq.#{tax_number}&order=created_at.desc&select=id&limit=1")
      return nil unless data.is_a?(Array) && data.first.is_a?(Hash)

      data.first["id"].to_s.presence
    rescue StandardError
      nil
    end
  end
end
