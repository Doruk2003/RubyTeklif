module CalendarEvents
  class Create
    def initialize(client: nil, repository: nil)
      @repository = repository || CalendarEvents::Repository.new(client: client)
    end

    def call(form_payload:, user_id:)
      form = CalendarEvents::CreateForm.new(form_payload)
      validate_form!(form)

      payload = form.normalized_attributes.merge(
        user_id: user_id,
        created_at: Time.now.utc.iso8601,
        updated_at: Time.now.utc.iso8601
      )
      created = @repository.create!(payload: payload)
      raise_from_response!(created, fallback: "Etkinlik olusturulamadi.")

      row = extract_row(created)
      raise ServiceErrors::System.new(user_message: "Etkinlik kaydi alinamadi.") if row.nil?

      row
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

    def extract_row(response)
      return response.first if response.is_a?(Array) && response.first.is_a?(Hash)
      return response if response.is_a?(Hash) && response["id"].present?

      nil
    end
  end
end
