module Offers
  class FormQuery
    def initialize(client:)
      @client = client
    end

    def companies
      data = @client.get("companies?deleted_at=is.null&select=id,name&order=name.asc")
      data.is_a?(Array) ? data : []
    end

    def products(category_id:)
      filters = ["active=eq.true", "deleted_at=is.null"]
      if category_id.to_s.present?
        filters << "category_id=eq.#{category_id}"
      end

      path = "products?select=id,name,category_id,categories(name),price&order=name.asc&#{filters.join('&')}"
      data = @client.get(path)
      data.is_a?(Array) ? data : []
    end
  end
end
