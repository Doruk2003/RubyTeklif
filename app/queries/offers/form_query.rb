module Offers
  class FormQuery
    def initialize(client:)
      @client = client
    end

    def companies
      data = @client.get("companies?select=id,name&order=name.asc")
      data.is_a?(Array) ? data : []
    end

    def products(company_id:, category:)
      filters = ["active=eq.true"]
      filters << "company_id=eq.#{company_id}" if company_id.to_s.present?
      if category.to_s.present? && ProductCategories::VALUES.include?(category.to_s)
        filters << "category=eq.#{category}"
      end

      path = "products?select=id,name,category,price&order=name.asc&#{filters.join('&')}"
      data = @client.get(path)
      data.is_a?(Array) ? data : []
    end
  end
end
