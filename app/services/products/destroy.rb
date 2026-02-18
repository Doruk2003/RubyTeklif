module Products
  class Destroy
    include ServiceSupport

    def initialize(client: nil, repository: nil)
      @repository = repository || Products::Repository.new(client: client)
    end

    def call(id:, actor_id:)
      archived = @repository.archive_with_audit_atomic(product_id: id, actor_id: actor_id)
      raise_from_response!(archived, fallback: "Urun arsivlenemedi.")
    end
  end
end
