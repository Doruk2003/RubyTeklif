module Offers
  class RestoreOffer
    def initialize(client:, restore_service_factory: ->(c) { Offers::Restore.new(client: c) })
      @client = client
      @restore_service_factory = restore_service_factory
    end

    def call(id:, actor_id:)
      @restore_service_factory.call(@client).call(id: id, actor_id: actor_id)
    end
  end
end
