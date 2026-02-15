module Products
  class Repository
    include AtomicRpc

    def initialize(client:)
      @client = client
    end

    def create_with_audit_atomic(payload:, actor_id:)
      call_atomic_rpc!(
        "rpc/create_product_with_audit_atomic",
        body: {
          p_actor_id: actor_id,
          p_name: payload[:name],
          p_price: payload[:price],
          p_vat_rate: payload[:vat_rate],
          p_item_type: payload[:item_type],
          p_category_id: payload[:category_id],
          p_active: payload[:active]
        }
      )
    end

    def update_with_audit_atomic(product_id:, payload:, actor_id:)
      call_atomic_rpc!(
        "rpc/update_product_with_audit_atomic",
        body: {
          p_actor_id: actor_id,
          p_product_id: product_id,
          p_name: payload[:name],
          p_price: payload[:price],
          p_vat_rate: payload[:vat_rate],
          p_item_type: payload[:item_type],
          p_category_id: payload[:category_id],
          p_active: payload[:active]
        }
      )
    end

    def archive_with_audit_atomic(product_id:, actor_id:)
      call_atomic_rpc!(
        "rpc/archive_product_with_audit_atomic",
        body: {
          p_actor_id: actor_id,
          p_product_id: product_id
        }
      )
    end

    def restore_with_audit_atomic(product_id:, actor_id:)
      call_atomic_rpc!(
        "rpc/restore_product_with_audit_atomic",
        body: {
          p_actor_id: actor_id,
          p_product_id: product_id
        }
      )
    end
  end
end
