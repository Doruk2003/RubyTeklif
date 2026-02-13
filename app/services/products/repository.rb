module Products
  class Repository
    def initialize(client:)
      @client = client
    end

    def create_with_audit_atomic(payload:, actor_id:)
      @client.post(
        "rpc/create_product_with_audit_atomic",
        body: {
          p_actor_id: actor_id,
          p_name: payload[:name],
          p_price: payload[:price],
          p_vat_rate: payload[:vat_rate],
          p_item_type: payload[:item_type],
          p_category_id: payload[:category_id],
          p_active: payload[:active]
        },
        headers: { "Prefer" => "return=representation" }
      )
    end

    def update_with_audit_atomic(product_id:, payload:, actor_id:)
      @client.post(
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
        },
        headers: { "Prefer" => "return=representation" }
      )
    end
  end
end
