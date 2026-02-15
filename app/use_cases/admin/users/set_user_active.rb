module Admin
  module Users
    # Orchestrates active/passive state changes in admin user management boundary.
    class SetUserActive
      def initialize(client:, set_active_service_factory: ->(c) { Admin::Users::SetActive.new(client: c) })
        @client = client
        @set_active_service_factory = set_active_service_factory
      end

      def call(id:, active:, actor_id:)
        @set_active_service_factory.call(@client).call(id: id, active: active, actor_id: actor_id)
      end
    end
  end
end
