module Admin
  module Users
    class SetActive
      def initialize(client:, audit_log: AuditLog.new(client: client))
        @client = client
        @audit_log = audit_log
      end

      def call(id:, active:, actor_id:)
        response = @client.patch("users?id=eq.#{id}", body: { active: active }, headers: { "Prefer" => "return=representation" })
        raise_from_response!(response, fallback: "Kullanici guncellenemedi.")

        @audit_log.log(
          action: active ? "users.enable" : "users.disable",
          actor_id: actor_id,
          target_id: id,
          target_type: "user",
          metadata: { active: active }
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
end

