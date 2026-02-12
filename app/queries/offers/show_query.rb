module Offers
  class ShowQuery
    def initialize(client: Supabase::Client.new(role: :service))
      @client = client
    end

    def call(id)
      data = @client.get("offers?id=eq.#{id}&select=id,offer_number,offer_date,net_total,vat_total,gross_total,status,companies(name),offer_items(id,description,quantity,unit_price,line_total,products(name,vat_rate))")
      data.is_a?(Array) ? data.first : nil
    end
  end
end
