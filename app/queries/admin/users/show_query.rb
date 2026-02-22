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
        unless data.is_a?(Array)
          raise ServiceErrors::System.new(user_message: "Kullanici bilgisi gecici olarak yuklenemedi. Lutfen tekrar deneyin.")
        end

        data.first
      rescue StandardError => e
        raise if e.is_a?(ServiceErrors::Base)

        raise ServiceErrors::System.new(user_message: "Kullanici bilgisi gecici olarak yuklenemedi. Lutfen tekrar deneyin.")
      end
    end
  end
end
