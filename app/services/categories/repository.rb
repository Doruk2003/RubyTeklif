module Categories
  class Repository
    include AtomicRpc

    def initialize(client:)
      @client = client
    end

    def create_with_audit_atomic(payload:, actor_id:)
      call_atomic_rpc!(
        "rpc/create_category_with_audit_atomic",
        body: {
          p_actor_id: actor_id,
          p_code: payload[:code],
          p_name: payload[:name],
          p_active: payload[:active]
        }
      )
    end

    def update_with_audit_atomic(category_id:, payload:, actor_id:)
      call_atomic_rpc!(
        "rpc/update_category_with_audit_atomic",
        body: {
          p_actor_id: actor_id,
          p_category_id: category_id,
          p_code: payload[:code],
          p_name: payload[:name],
          p_active: payload[:active]
        }
      )
    end

    def archive_with_audit_atomic(category_id:, actor_id:)
      call_atomic_rpc!(
        "rpc/archive_category_with_audit_atomic",
        body: {
          p_actor_id: actor_id,
          p_category_id: category_id
        }
      )
    end

    def restore_with_audit_atomic(category_id:, actor_id:)
      call_atomic_rpc!(
        "rpc/restore_category_with_audit_atomic",
        body: {
          p_actor_id: actor_id,
          p_category_id: category_id
        }
      )
    end
  end
end
