module Products
  class FormQuery
    def initialize(client:)
      @client = client
    end

    def find_product(id)
      data = @client.get("products?id=eq.#{id}&select=id,company_id,name,price,vat_rate,item_type,category,active")
      data.is_a?(Array) ? data.first : nil
    end

    def companies
      data = @client.get("companies?select=id,name&order=name.asc")
      data.is_a?(Array) ? data : []
    end
  end
end
