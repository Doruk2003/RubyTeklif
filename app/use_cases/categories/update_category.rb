module Categories
  class UpdateCategory
    def initialize(client:, update_service_factory: ->(c) { Categories::Update.new(client: c) })
      @client = client
      @update_service_factory = update_service_factory
    end

    def call(id:, form_payload:, actor_id:)
      @update_service_factory.call(@client).call(id: id, form_payload: form_payload, actor_id: actor_id)
    end
  end
end
