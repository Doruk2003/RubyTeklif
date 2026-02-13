module Offers
  class CreateOffer
    def initialize(
      client:,
      totals: Offers::TotalsCalculator.new,
      repository_factory: ->(c) { Offers::Repository.new(client: c) },
      create_service_factory: ->(repository, t) { Offers::Create.new(repository: repository, totals: t) }
    )
      @client = client
      @totals = totals
      @repository_factory = repository_factory
      @create_service_factory = create_service_factory
    end

    def call(payload:, user_id:)
      repository = @repository_factory.call(@client)
      @create_service_factory.call(repository, @totals).call(payload: payload, user_id: user_id)
    end
  end
end
