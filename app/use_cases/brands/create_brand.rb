module Brands
  class CreateBrand
    def initialize(client:, create_service_factory: ->(c) { Brands::Create.new(client: c) })
      @client = client
      @create_service_factory = create_service_factory
    end

    def call(form_payload:, actor_id:)
      @create_service_factory.call(@client).call(form_payload: form_payload, actor_id: actor_id)
    end
  end
end
