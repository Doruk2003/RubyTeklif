module Products
  class Restore
    include ServiceSupport

    def initialize(client: nil, repository: nil)
      @repository = repository || Products::Repository.new(client: client)
    end

    def call(id:, actor_id:)
      restored = @repository.restore_with_audit_atomic(product_id: id, actor_id: actor_id)
      raise_from_response!(restored, fallback: "Urun geri yuklenemedi.")
    end
  end
end
