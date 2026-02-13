module Admin
  module Users
    class UpdateRole
      def initialize(client:, audit_log: AuditLog.new(client: client))
        @client = client
        @audit_log = audit_log
      end

      def call(id:, role:, actor_id:)
        role = role.to_s.presence || Roles::ADMIN
        response = @client.patch("users?id=eq.#{id}", body: { role: role }, headers: { "Prefer" => "return=representation" })
        raise_from_response!(response, fallback: "Kullanici guncellenemedi.")

        @audit_log.log(
          action: "users.role_change",
          actor_id: actor_id,
          target_id: id,
          target_type: "user",
          metadata: { role: role }
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

