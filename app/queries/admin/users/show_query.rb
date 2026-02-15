module Admin
  module Users
    # Fetches a single user row for admin edit screens.
    class ShowQuery
      def initialize(client:)
        @client = client
      end

      # :reek:FeatureEnvy
      def call(id:)
        data = @client.get("users?id=eq.#{Supabase::FilterValue.eq(id)}&select=id,email,role&limit=1")
        return nil unless data.is_a?(Array)

        data.first
      rescue StandardError
        nil
      end
    end
  end
end
