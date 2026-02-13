module Currencies
  class ShowQuery
    def initialize(client:)
      @client = client
    end

    def call(id)
      data = @client.get("currencies?id=eq.#{Supabase::FilterValue.eq(id)}&deleted_at=is.null&select=id,code,name,symbol,rate_to_try,active")
      data.is_a?(Array) ? data.first : nil
    end
  end
end
