module Admin
  module Users
    class ResetPassword
      def initialize(client:, auth: Supabase::Auth.new, audit_log: AuditLog.new(client: client))
        @client = client
        @auth = auth
        @audit_log = audit_log
      end

      def call(id:, actor_id:)
        data = @client.get("users?id=eq.#{Supabase::FilterValue.eq(id)}&select=email&limit=1")
        user = data.is_a?(Array) ? data.first : nil
        email = user.is_a?(Hash) ? user["email"].to_s : ""
        raise ServiceErrors::Validation.new(user_message: "E-posta bulunamadi.") if email.blank?

        @auth.send_recovery(email: email)

        @audit_log.log(
          action: "users.reset_password",
          actor_id: actor_id,
          target_id: id,
          target_type: "user",
          metadata: { email: email }
        )
      rescue Supabase::Auth::AuthError => e
        raise ServiceErrors::System.new(user_message: e.message)
      end
    end
  end
end
