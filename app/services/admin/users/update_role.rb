module Admin
  module Users
    class UpdateRole
      ALLOWED_ROLES = Roles::ACCEPTED_ROLES

      def initialize(client:, audit_log: AuditLog.new(client: client))
        @client = client
        @audit_log = audit_log
      end

      def call(id:, role:, actor_id:)
        role = role.to_s.presence || Roles::ADMIN
        validate_role!(role)
        ensure_last_active_admin_not_demoted!(id: id, role: role)

        response = @client.patch("users?id=eq.#{Supabase::FilterValue.eq(id)}", body: { role: role }, headers: { "Prefer" => "return=representation" })
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

      def validate_role!(role)
        return if ALLOWED_ROLES.include?(role)

        raise ServiceErrors::Validation.new(user_message: "Gecersiz rol secimi.")
      end

      def ensure_last_active_admin_not_demoted!(id:, role:)
        return if role == Roles::ADMIN

        target_user = find_user!(id: id)
        return unless target_user["role"].to_s == Roles::ADMIN
        return unless truthy?(target_user["active"])
        return unless active_admin_count <= 1

        raise ServiceErrors::Validation.new(user_message: "Son aktif adminin rolu degistirilemez.")
      end

      def find_user!(id:)
        response = @client.get("users?id=eq.#{Supabase::FilterValue.eq(id)}&select=id,role,active&limit=1")
        raise_from_response!(response, fallback: "Kullanici bilgisi okunamadi.")

        user = response.is_a?(Array) ? response.first : nil
        raise ServiceErrors::Validation.new(user_message: "Kullanici bulunamadi.") if user.nil?

        user
      end

      def active_admin_count
        response = @client.get("users?select=id&role=eq.#{Roles::ADMIN}&active=eq.true")
        raise_from_response!(response, fallback: "Admin sayisi hesaplanamadi.")
        return response.size if response.is_a?(Array)

        0
      end

      def truthy?(value)
        value == true || value.to_s == "true"
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
end
