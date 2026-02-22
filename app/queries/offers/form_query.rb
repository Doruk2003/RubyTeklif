module Offers
  class FormQuery
    def initialize(client:)
      @client = client
    end

    def companies(user_id:)
      return [] if user_id.to_s.blank?

      data = Rails.cache.fetch("offers/form/companies/v1/user:#{user_id}", expires_in: 1.minute) do
        @client.get("companies?deleted_at=is.null&select=id,name&order=name.asc")
      end
      return data if data.is_a?(Array)

      raise ServiceErrors::System.new(user_message: "Teklif firma listesi gecici olarak yuklenemedi. Lutfen tekrar deneyin.")
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
      data = Rails.cache.fetch("offers/form/products/v1/user:#{user_id}/category:#{category_part}", expires_in: 1.minute) do
        @client.get(path)
      end
      return data if data.is_a?(Array)

      raise ServiceErrors::System.new(user_message: "Teklif urun listesi gecici olarak yuklenemedi. Lutfen tekrar deneyin.")
    end
  end
end
