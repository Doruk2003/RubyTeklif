module Admin
  module Users
    # Builds a simple actor_id => email lookup table for admin logs list.
    class EmailIndexQuery
      def initialize(client:)
        @client = client
      end

      # :reek:FeatureEnvy
      def call
        data = @client.get("users?select=id,email&order=email.asc")
        unless data.is_a?(Array)
          raise ServiceErrors::System.new(user_message: "Kullanici e-posta listesi gecici olarak yuklenemedi. Lutfen tekrar deneyin.")
        end

        data.each_with_object({}) do |row, acc|
          acc[row["id"].to_s] = row["email"].to_s
        end
      rescue StandardError => e
        raise if e.is_a?(ServiceErrors::Base)

        raise ServiceErrors::System.new(user_message: "Kullanici e-posta listesi gecici olarak yuklenemedi. Lutfen tekrar deneyin.")
      end
    end
  end
end
