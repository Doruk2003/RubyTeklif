module CalendarEvents
  class Destroy
    def initialize(client: nil, repository: nil)
      @repository = repository || CalendarEvents::Repository.new(client: client)
    end

    def call(id:, user_id:)
      deleted = @repository.soft_delete!(id: id, user_id: user_id)
      raise_from_response!(deleted, fallback: "Etkinlik silinemedi.")
      true
    end

    private

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
