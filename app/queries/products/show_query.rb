module Products
  class ShowQuery
    def initialize(client:)
      @client = client
    end

    def call(id)
      data = @client.get("products?id=eq.#{Supabase::FilterValue.eq(id)}&deleted_at=is.null&select=id,sku,name,description,barcode,gtip_code,price,cost_price,stock_quantity,min_stock_level,vat_rate,item_type,category_id,brand_id,currency_id,unit,is_stock_item,sale_price_vat_included,cost_price_vat_included,active,categories(name),brands(name),currencies(code,name,symbol)")
      data.is_a?(Array) ? data.first : nil
    end

    def fetch_offer_movements(product_id, user_id:)
      # Fetch offer items for this product, joining with offers and companies
      # select=unit_price,offers(offer_number,offer_date,status,companies(name))
      query = "offer_items?product_id=eq.#{Supabase::FilterValue.eq(product_id)}&user_id=eq.#{Supabase::FilterValue.eq(user_id)}&select=unit_price,offer_id,offers(id,offer_number,offer_date,status,companies(id,name))&order=offers(offer_date).desc"
      @client.get(query) || []
    end
  end
end
