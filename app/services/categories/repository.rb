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

    def update_with_audit_atomic(category_id:, payload:, actor_id:)
      @client.post(
        "rpc/update_category_with_audit_atomic",
        body: {
          p_actor_id: actor_id,
          p_category_id: category_id,
          p_code: payload[:code],
          p_name: payload[:name],
          p_active: payload[:active]
        },
        headers: { "Prefer" => "return=representation" }
      )
    end

    def archive_with_audit_atomic(category_id:, actor_id:)
      @client.post(
        "rpc/archive_category_with_audit_atomic",
        body: {
          p_actor_id: actor_id,
          p_category_id: category_id
        },
        headers: { "Prefer" => "return=representation" }
      )
    end

    def restore_with_audit_atomic(category_id:, actor_id:)
      @client.post(
        "rpc/restore_category_with_audit_atomic",
        body: {
          p_actor_id: actor_id,
          p_category_id: category_id
        },
        headers: { "Prefer" => "return=representation" }
      )
    end
  end
end
