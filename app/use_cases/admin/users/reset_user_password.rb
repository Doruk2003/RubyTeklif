module Admin
  module Users
    # Orchestrates password reset request flow in admin user management boundary.
    class ResetUserPassword
      def initialize(client:, reset_service_factory: ->(c) { Admin::Users::ResetPassword.new(client: c) })
        @client = client
        @reset_service_factory = reset_service_factory
      end

      def call(id:, actor_id:)
        @reset_service_factory.call(@client).call(id: id, actor_id: actor_id)
      end
    end
  end
end
