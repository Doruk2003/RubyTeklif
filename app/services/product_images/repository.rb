module ProductImages
  class Repository
    def initialize(client:)
      @client = client
    end

    def list(product_id:, user_id:)
      path = "product_images?select=id,product_id,storage_path,file_name,content_type,byte_size,sort_order,created_at" \
             "&product_id=eq.#{Supabase::FilterValue.eq(product_id)}" \
             "&user_id=eq.#{Supabase::FilterValue.eq(user_id)}" \
             "&deleted_at=is.null" \
             "&order=sort_order.asc,created_at.asc"

      data = @client.get(path)
      data.is_a?(Array) ? data : []
    end

    def create!(payload)
      @client.post("product_images", body: payload, headers: { "Prefer" => "return=representation" })
    end

    def find_active(image_id:, product_id:, user_id:)
      path = "product_images?select=id,product_id,user_id,storage_path,sort_order" \
             "&id=eq.#{Supabase::FilterValue.eq(image_id)}" \
             "&product_id=eq.#{Supabase::FilterValue.eq(product_id)}" \
             "&user_id=eq.#{Supabase::FilterValue.eq(user_id)}" \
             "&deleted_at=is.null&limit=1"
      data = @client.get(path)
      data.is_a?(Array) ? data.first : nil
    end

    def update_active!(image_id:, product_id:, user_id:, attrs:)
      path = "product_images?id=eq.#{Supabase::FilterValue.eq(image_id)}" \
             "&product_id=eq.#{Supabase::FilterValue.eq(product_id)}" \
             "&user_id=eq.#{Supabase::FilterValue.eq(user_id)}" \
             "&deleted_at=is.null"
      @client.patch(path, body: attrs, headers: { "Prefer" => "return=representation" })
    end

    def soft_delete_by_product!(product_id:, user_id:, timestamp:)
      path = "product_images?product_id=eq.#{Supabase::FilterValue.eq(product_id)}" \
             "&user_id=eq.#{Supabase::FilterValue.eq(user_id)}" \
             "&deleted_at=is.null"
      @client.patch(path, body: { deleted_at: timestamp, updated_at: timestamp }, headers: { "Prefer" => "return=minimal" })
    end
  end
end
