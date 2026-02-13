module Offers
  class Restore
    def initialize(client: nil, repository: nil)
      @repository = repository || Offers::Repository.new(client: client)
    end

    def call(id:, actor_id:)
      restored = @repository.restore_with_audit_atomic(offer_id: id, actor_id: actor_id)
      raise_from_response!(restored, fallback: "Teklif geri yuklenemedi.")
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
