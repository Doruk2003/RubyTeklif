module ProductImages
  class PurgeForProduct
    def initialize(client:, access_token:, repository: nil, storage_client: nil, bucket: ENV.fetch("SUPABASE_PRODUCTS_BUCKET", "product-images"))
      @repository = repository || ProductImages::Repository.new(client: client)
      @storage_client = storage_client || Supabase::StorageClient.new(access_token: access_token)
      @bucket = bucket
    end

    def call(product_id:, user_id:)
      rows = @repository.list(product_id: product_id, user_id: user_id)
      return 0 if rows.empty?

      rows.each do |row|
        @storage_client.delete(bucket: @bucket, path: row["storage_path"].to_s)
      end

      timestamp = Time.now.utc.iso8601
      @repository.soft_delete_by_product!(product_id: product_id, user_id: user_id, timestamp: timestamp)
      rows.size
    rescue Supabase::StorageClient::StorageError => e
      raise ServiceErrors::System.new(user_message: "Urun fotograflari temizlenemedi: #{e.message}")
    end
  end
end
