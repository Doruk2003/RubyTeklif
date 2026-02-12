module Users
  class Repository
    def initialize(client: Supabase::Client.new(role: :service))
      @client = client
    end

    def find_by_id(user_id)
      data = @client.get("users?id=eq.#{user_id}&select=id,email,role,active&limit=1")
      data.is_a?(Array) ? data.first : nil
    end
  end
end
