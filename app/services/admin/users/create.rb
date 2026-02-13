module Admin
  module Users
    class Create
      def initialize(client:, auth: Supabase::Auth.new, audit_log: AuditLog.new(client: client))
        @client = client
        @auth = auth
        @audit_log = audit_log
      end

      def call(form_payload:, actor_id:)
        form = Admin::Users::CreateForm.new(form_payload)
        validate_form!(form)

        created = @auth.create_user(email: form.email, password: form.password, role: form.role)
        user_id = created.is_a?(Hash) ? (created["id"].presence || created.dig("user", "id").to_s) : nil
        raise ServiceErrors::System.new(user_message: "Kullanici olusturulamadi.") if user_id.blank?

        inserted = @client.post("users", body: { id: user_id, email: form.email, role: form.role, active: true }, headers: { "Prefer" => "return=minimal" })
        raise_from_response!(inserted, fallback: "Kullanici olusturulamadi.")

        @audit_log.log(
          action: "users.create",
          actor_id: actor_id,
          target_id: user_id,
          target_type: "user",
          metadata: { role: form.role, email: form.email }
        )

        user_id
      rescue Supabase::Auth::AuthError => e
        message = e.message.to_s
        if message.downcase.include?("already") || message.downcase.include?("registered")
          raise ServiceErrors::Validation.new(user_message: "Bu e-posta zaten kayitli.")
        end

        raise ServiceErrors::System.new(user_message: message)
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
    end
  end
end

