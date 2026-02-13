module Offers
  class ShowQuery
    def initialize(client:)
      @client = client
    end

    def call(id)
      data = @client.get("offers?id=eq.#{Supabase::FilterValue.eq(id)}&offer_items.deleted_at=is.null&select=id,offer_number,offer_date,net_total,vat_total,gross_total,status,deleted_at,companies(name),offer_items(id,description,quantity,unit_price,discount_rate,line_total,products(name,vat_rate))")
      data.is_a?(Array) ? data.first : nil
    end
  end
end
