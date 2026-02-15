module Admin
  module Users
    # Orchestrates role update action in admin user management boundary.
    class UpdateUserRole
      def initialize(client:, update_service_factory: ->(c) { Admin::Users::UpdateRole.new(client: c) })
        @client = client
        @update_service_factory = update_service_factory
      end

      def call(id:, role:, actor_id:)
        @update_service_factory.call(@client).call(id: id, role: role, actor_id: actor_id)
      end
    end
  end
end
