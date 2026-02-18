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
          p_sku: payload[:sku],
          p_name: payload[:name],
          p_description: payload[:description],
          p_barcode: payload[:barcode],
          p_price: payload[:price],
          p_cost_price: payload[:cost_price],
          p_stock_quantity: payload[:stock_quantity],
          p_min_stock_level: payload[:min_stock_level],
          p_vat_rate: payload[:vat_rate],
          p_item_type: payload[:item_type],
          p_category_id: payload[:category_id],
          p_brand_id: payload[:brand_id],
          p_currency_id: payload[:currency_id],
          p_unit: payload[:unit],
          p_is_stock_item: payload[:is_stock_item],
          p_sale_price_vat_included: payload[:sale_price_vat_included],
          p_cost_price_vat_included: payload[:cost_price_vat_included],
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
          p_sku: payload[:sku],
          p_name: payload[:name],
          p_description: payload[:description],
          p_barcode: payload[:barcode],
          p_price: payload[:price],
          p_cost_price: payload[:cost_price],
          p_stock_quantity: payload[:stock_quantity],
          p_min_stock_level: payload[:min_stock_level],
          p_vat_rate: payload[:vat_rate],
          p_item_type: payload[:item_type],
          p_category_id: payload[:category_id],
          p_brand_id: payload[:brand_id],
          p_currency_id: payload[:currency_id],
          p_unit: payload[:unit],
          p_is_stock_item: payload[:is_stock_item],
          p_sale_price_vat_included: payload[:sale_price_vat_included],
          p_cost_price_vat_included: payload[:cost_price_vat_included],
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
