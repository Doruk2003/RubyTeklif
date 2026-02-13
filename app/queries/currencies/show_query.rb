module Currencies
  class ShowQuery
    def initialize(client:)
      @client = client
    end

    def call(id)
      data = @client.get("currencies?id=eq.#{id}&select=id,code,name,symbol,rate_to_try,active")
      data.is_a?(Array) ? data.first : nil
    end
  end
end

