module Categories
  class ShowQuery
    def initialize(client:)
      @client = client
    end

    def call(id)
      rows = @client.get("categories?id=eq.#{Supabase::FilterValue.eq(id)}&select=id,code,name,active,deleted_at&limit=1")
      rows.is_a?(Array) ? rows.first : nil
    end
  end
end
