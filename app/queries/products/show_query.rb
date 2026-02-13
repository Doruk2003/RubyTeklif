module Products
  class ShowQuery
    def initialize(client:)
      @client = client
    end

    def call(id)
      data = @client.get("products?id=eq.#{id}&select=id,company_id,name,price,vat_rate,item_type,category,active,companies(name)")
      data.is_a?(Array) ? data.first : nil
    end
  end
end
