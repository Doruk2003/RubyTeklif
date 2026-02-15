module Categories
  class OptionsQuery
    def initialize(client:)
      @client = client
    end

    def call(active_only: true, user_id:)
      return [] if user_id.to_s.blank?

      filters = []
      filters << "active=eq.true" if active_only
      path = "categories?deleted_at=is.null&select=id,code,name,active&order=name.asc"
      path = "#{path}&#{filters.join('&')}" if filters.any?

      cache_key = "categories/options/v1/user:#{user_id}/active:#{active_only ? 1 : 0}"
      data = Rails.cache.fetch(cache_key, expires_in: 2.minutes) do
        @client.get(path)
      end
      data.is_a?(Array) ? data : []
    end
  end
end
