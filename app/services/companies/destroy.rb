module Companies
  class Destroy
    def initialize(client:, audit_log: AuditLog.new(client: client))
      @client = client
      @audit_log = audit_log
    end

    def call(id:, actor_id:)
      archived = @client.patch(
        "companies?id=eq.#{id}&deleted_at=is.null",
        body: { deleted_at: Time.now.utc.iso8601 },
        headers: { "Prefer" => "return=minimal" }
      )
      raise_from_response!(archived, fallback: "Musteri arsivlenemedi.")

      @audit_log.log(
        action: "companies.archive",
        actor_id: actor_id,
        target_id: id,
        target_type: "company",
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
