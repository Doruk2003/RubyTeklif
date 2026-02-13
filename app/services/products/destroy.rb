module Products
  class Destroy
    def initialize(client:, audit_log: AuditLog.new(client: client))
      @client = client
      @audit_log = audit_log
    end

    def call(id:, actor_id:)
      deleted = @client.delete("products?id=eq.#{id}", headers: { "Prefer" => "return=minimal" })
      raise_from_response!(deleted, fallback: "Urun silinemedi.")

      @audit_log.log(
        action: "products.delete",
        actor_id: actor_id,
        target_id: id,
        target_type: "product",
        metadata: {}
      )
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
