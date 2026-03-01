module Companies
  class OptionsQuery
    def initialize(client:)
      @client = client
    end

    def call(active_only: true, user_id: nil, q: nil)
      filters = ["deleted_at=is.null"]
      filters << "active=eq.true" if active_only

      if q.present?
        escaped_q = q.to_s.gsub("%", "\\%").gsub("_", "\\_")
        filters << "name=ilike.*#{escaped_q}*"
      end

      path = "companies?select=id,name&order=name.asc"
      path += "&#{filters.join('&')}" if filters.any?
      path << "&limit=20" # Limit results for better performance

      # Optional caching if needed, but let's keep it simple first
      data = @client.get(path)
      return data if data.is_a?(Array)

      []
    rescue StandardError
      []
    end
  end
end
