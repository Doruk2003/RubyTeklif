module Admin
  module Users
    class ResetPassword
      def initialize(client:, auth: Supabase::Auth.new)
        @client = client
        @auth = auth
      end

      def call(id:)
        data = @client.get("users?id=eq.#{id}&select=email&limit=1")
        user = data.is_a?(Array) ? data.first : nil
        email = user.is_a?(Hash) ? user["email"].to_s : ""
        raise ServiceErrors::Validation.new(user_message: "E-posta bulunamadi.") if email.blank?

        @auth.send_recovery(email: email)
      rescue Supabase::Auth::AuthError => e
        raise ServiceErrors::System.new(user_message: e.message)
      end
    end
  end
end

