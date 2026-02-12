module Offers
  class IndexQuery
    def initialize(client: Supabase::Client.new(role: :service))
      @client = client
    end

    def call
      data = @client.get("offers?select=id,offer_number,offer_date,gross_total,status,companies(name)&order=offer_date.desc")
      data.is_a?(Array) ? data : []
    end
  end
end
