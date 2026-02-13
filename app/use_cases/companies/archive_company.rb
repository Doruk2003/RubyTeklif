module Companies
  class ArchiveCompany
    def initialize(client:, destroy_service_factory: ->(c) { Companies::Destroy.new(client: c) })
      @client = client
      @destroy_service_factory = destroy_service_factory
    end

    def call(id:, actor_id:)
      @destroy_service_factory.call(@client).call(id: id, actor_id: actor_id)
    end
  end
end
