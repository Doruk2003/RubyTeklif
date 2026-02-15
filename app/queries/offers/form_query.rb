module Offers
  class FormQuery
    def initialize(client:)
      @client = client
    end

    def companies(user_id:)
      return [] if user_id.to_s.blank?

      data = Rails.cache.fetch("offers/form/companies/v1/user:#{user_id}", expires_in: 2.minutes) do
        @client.get("companies?deleted_at=is.null&select=id,name&order=name.asc")
      end
      data.is_a?(Array) ? data : []
    end

    def products(category_id:, user_id:)
      return [] if user_id.to_s.blank?

      category_value = category_id.to_s
      filters = ["active=eq.true", "deleted_at=is.null"]
      if category_value.present?
        filters << "category_id=eq.#{Supabase::FilterValue.eq(category_value)}"
      end

      path = "products?select=id,name,category_id,categories(name),price&order=name.asc&#{filters.join('&')}"
      category_part = category_value.presence || "all"
      data = Rails.cache.fetch("offers/form/products/v1/user:#{user_id}/category:#{category_part}", expires_in: 2.minutes) do
        @client.get(path)
      end
      data.is_a?(Array) ? data : []
    end
  end
end
