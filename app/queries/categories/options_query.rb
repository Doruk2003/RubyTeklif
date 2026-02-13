module Categories
  class OptionsQuery
    def initialize(client:)
      @client = client
    end

    def call(active_only: true)
      filters = []
      filters << "active=eq.true" if active_only
      path = "categories?deleted_at=is.null&select=id,code,name,active&order=name.asc"
      path = "#{path}&#{filters.join('&')}" if filters.any?

      data = @client.get(path)
      data.is_a?(Array) ? data : []
    end
  end
end
