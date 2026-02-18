module ProductImages
  class Remove
    def initialize(client:, access_token:, repository: nil, storage_client: nil, bucket: ENV.fetch("SUPABASE_PRODUCTS_BUCKET", "product-images"))
      @repository = repository || ProductImages::Repository.new(client: client)
      @storage_client = storage_client || Supabase::StorageClient.new(access_token: access_token)
      @bucket = bucket
    end

    def call(product_id:, image_id:, user_id:)
      image = @repository.find_active(image_id: image_id, product_id: product_id, user_id: user_id)
      if image.blank?
        raise ServiceErrors::Validation.new(user_message: "Fotograf bulunamadi.")
      end

      @storage_client.delete(bucket: @bucket, path: image["storage_path"].to_s)

      @repository.update_active!(
        image_id: image_id,
        product_id: product_id,
        user_id: user_id,
        attrs: { deleted_at: Time.now.utc.iso8601, updated_at: Time.now.utc.iso8601 }
      )

      normalize_sort_order!(product_id: product_id, user_id: user_id)
      true
    rescue Supabase::StorageClient::StorageError => e
      raise ServiceErrors::System.new(user_message: "Fotograf dosyasi silinemedi: #{e.message}")
    end

    private

    def normalize_sort_order!(product_id:, user_id:)
      rows = @repository.list(product_id: product_id, user_id: user_id)
      rows.each_with_index do |row, index|
        desired = index + 1
        current = row["sort_order"].to_i
        next if current == desired

        @repository.update_active!(
          image_id: row["id"],
          product_id: product_id,
          user_id: user_id,
          attrs: { sort_order: desired, updated_at: Time.now.utc.iso8601 }
        )
      end
    end
  end
end
