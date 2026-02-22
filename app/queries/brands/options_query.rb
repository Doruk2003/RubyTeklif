module Brands
  class OptionsQuery
    def initialize(client:)
      @client = client
    end

    def call(active_only: true, user_id:)
      return [] if user_id.to_s.blank?

      filters = []
      filters << "active=eq.true" if active_only
      path = "brands?deleted_at=is.null&select=id,code,name,active&order=name.asc"
      path = "#{path}&#{filters.join('&')}" if filters.any?

      cache_key = "brands/options/v1/user:#{user_id}/active:#{active_only ? 1 : 0}"
      data = Rails.cache.fetch(cache_key, expires_in: 1.minute) do
        @client.get(path)
      end
      return data if data.is_a?(Array)

      raise ServiceErrors::System.new(user_message: "Marka secenekleri gecici olarak yuklenemedi. Lutfen tekrar deneyin.")
    end
  end
end
