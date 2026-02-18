require "securerandom"

module ProductImages
  class Attach
    MAX_PHOTO_COUNT = 6
    MAX_FILE_SIZE_BYTES = 10 * 1024 * 1024

    def initialize(client:, access_token:, repository: nil, storage_client: nil, bucket: ENV.fetch("SUPABASE_PRODUCTS_BUCKET", "product-images"))
      @client = client
      @repository = repository || ProductImages::Repository.new(client: client)
      @storage_client = storage_client || Supabase::StorageClient.new(access_token: access_token)
      @bucket = bucket
    end

    def call(product_id:, user_id:, files:)
      upload_files = Array(files).compact.reject { |f| blank_file?(f) }
      return [] if upload_files.empty?

      existing = @repository.list(product_id: product_id, user_id: user_id)
      total = existing.size + upload_files.size
      if total > MAX_PHOTO_COUNT
        raise ServiceErrors::Validation.new(
          user_message: "En fazla #{MAX_PHOTO_COUNT} urun fotografi yukleyebilirsiniz. Mevcut: #{existing.size}, yeni: #{upload_files.size}."
        )
      end

      created = []
      upload_files.each_with_index do |file, index|
        validate_file!(file)
        storage_path = build_storage_path(user_id: user_id, product_id: product_id, file: file)
        io = file.respond_to?(:tempfile) ? file.tempfile : file
        io.rewind if io.respond_to?(:rewind)

        @storage_client.upload(
          bucket: @bucket,
          path: storage_path,
          io: io,
          content_type: file.content_type
        )

        payload = {
          user_id: user_id,
          product_id: product_id,
          storage_path: storage_path,
          file_name: file.original_filename.to_s,
          content_type: file.content_type.to_s,
          byte_size: file.size.to_i,
          sort_order: existing.size + index + 1
        }
        created << @repository.create!(payload)
      end

      created
    rescue Supabase::StorageClient::StorageError => e
      raise ServiceErrors::System.new(user_message: "Fotograf yuklenemedi: #{e.message}")
    end

    private

    def blank_file?(file)
      file.respond_to?(:original_filename) && file.original_filename.to_s.strip.empty?
    end

    def validate_file!(file)
      content_type = file.content_type.to_s.downcase
      unless content_type.start_with?("image/")
        raise ServiceErrors::Validation.new(user_message: "Sadece gorsel dosyasi yukleyebilirsiniz.")
      end

      if file.size.to_i <= 0
        raise ServiceErrors::Validation.new(user_message: "Bos dosya yuklenemez.")
      end

      if file.size.to_i > MAX_FILE_SIZE_BYTES
        raise ServiceErrors::Validation.new(user_message: "Tek bir fotograf en fazla 10 MB olabilir.")
      end
    end

    def build_storage_path(user_id:, product_id:, file:)
      ext = File.extname(file.original_filename.to_s).to_s.downcase
      ext = ".jpg" if ext.blank?
      ext = ".jpg" unless ext.match?(/\A\.[a-z0-9]+\z/)
      "#{user_id}/products/#{product_id}/#{Time.now.to_i}_#{SecureRandom.hex(8)}#{ext}"
    end
  end
end
