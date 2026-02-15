module Categories
  class Repository
    def initialize(client:)
      @client = client
    end

    def create_with_audit_atomic(payload:, actor_id:)
      @client.post(
        "rpc/create_category_with_audit_atomic",
        body: {
          p_actor_id: actor_id,
          p_code: payload[:code],
          p_name: payload[:name],
          p_active: payload[:active]
        },
        headers: { "Prefer" => "return=representation" }
      )
    end
  end
end
