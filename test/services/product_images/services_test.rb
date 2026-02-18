require "test_helper"

module ProductImages
  class ServicesTest < ActiveSupport::TestCase
    class FakeRepository
      attr_reader :updated_rows, :soft_deleted

      def initialize(rows: [], find_row: nil)
        @rows = rows
        @find_row = find_row
        @updated_rows = []
        @soft_deleted = nil
      end

      def list(product_id:, user_id:)
        @rows
      end

      def find_active(image_id:, product_id:, user_id:)
        @find_row
      end

      def update_active!(image_id:, product_id:, user_id:, attrs:)
        @updated_rows << { image_id: image_id, attrs: attrs }
        true
      end

      def soft_delete_by_product!(product_id:, user_id:, timestamp:)
        @soft_deleted = { product_id: product_id, user_id: user_id, timestamp: timestamp }
        true
      end
    end

    class FakeStorageClient
      attr_reader :deleted_paths

      def initialize(fail_on: nil)
        @fail_on = fail_on
        @deleted_paths = []
      end

      def delete(bucket:, path:)
        if @fail_on.present? && path.to_s.include?(@fail_on)
          raise Supabase::StorageClient::StorageError, "forced delete error"
        end

        @deleted_paths << { bucket: bucket, path: path }
        true
      end
    end

    test "remove deletes from storage and soft deletes metadata" do
      repo = FakeRepository.new(find_row: { "id" => "img-1", "storage_path" => "usr/products/prd/a.jpg" }, rows: [])
      storage = FakeStorageClient.new

      service = ProductImages::Remove.new(client: nil, access_token: "token", repository: repo, storage_client: storage, bucket: "product-images")
      result = service.call(product_id: "prd-1", image_id: "img-1", user_id: "usr-1")

      assert_equal true, result
      assert_equal 1, storage.deleted_paths.size
      assert_equal "usr/products/prd/a.jpg", storage.deleted_paths.first[:path]
      assert_equal "img-1", repo.updated_rows.first[:image_id]
      assert repo.updated_rows.first[:attrs].key?(:deleted_at)
    end

    test "remove raises validation when image not found" do
      repo = FakeRepository.new(find_row: nil)
      storage = FakeStorageClient.new
      service = ProductImages::Remove.new(client: nil, access_token: "token", repository: repo, storage_client: storage, bucket: "product-images")

      assert_raises(ServiceErrors::Validation) do
        service.call(product_id: "prd-1", image_id: "missing", user_id: "usr-1")
      end
    end

    test "reorder swaps adjacent image sort orders for move up" do
      rows = [
        { "id" => "img-1", "sort_order" => 1 },
        { "id" => "img-2", "sort_order" => 2 }
      ]
      repo = FakeRepository.new(rows: rows)

      service = ProductImages::Reorder.new(client: nil, repository: repo)
      result = service.move(product_id: "prd-1", image_id: "img-2", user_id: "usr-1", direction: "up")

      assert_equal true, result
      assert_equal 2, repo.updated_rows.size
      assert_equal "img-2", repo.updated_rows.first[:image_id]
      assert_equal 1, repo.updated_rows.first[:attrs][:sort_order]
      assert_equal "img-1", repo.updated_rows.second[:image_id]
      assert_equal 2, repo.updated_rows.second[:attrs][:sort_order]
    end

    test "reorder no-ops when moving first image up" do
      rows = [
        { "id" => "img-1", "sort_order" => 1 },
        { "id" => "img-2", "sort_order" => 2 }
      ]
      repo = FakeRepository.new(rows: rows)

      service = ProductImages::Reorder.new(client: nil, repository: repo)
      result = service.move(product_id: "prd-1", image_id: "img-1", user_id: "usr-1", direction: "up")

      assert_equal true, result
      assert_empty repo.updated_rows
    end

    test "purge_for_product hard deletes all files and soft deletes metadata in batch" do
      rows = [
        { "id" => "img-1", "storage_path" => "usr/products/prd/a.jpg" },
        { "id" => "img-2", "storage_path" => "usr/products/prd/b.jpg" }
      ]
      repo = FakeRepository.new(rows: rows)
      storage = FakeStorageClient.new

      service = ProductImages::PurgeForProduct.new(client: nil, access_token: "token", repository: repo, storage_client: storage, bucket: "product-images")
      count = service.call(product_id: "prd-1", user_id: "usr-1")

      assert_equal 2, count
      assert_equal 2, storage.deleted_paths.size
      assert_equal "prd-1", repo.soft_deleted[:product_id]
      assert_equal "usr-1", repo.soft_deleted[:user_id]
    end

    test "purge_for_product returns zero when no image exists" do
      repo = FakeRepository.new(rows: [])
      storage = FakeStorageClient.new
      service = ProductImages::PurgeForProduct.new(client: nil, access_token: "token", repository: repo, storage_client: storage, bucket: "product-images")

      count = service.call(product_id: "prd-1", user_id: "usr-1")
      assert_equal 0, count
      assert_empty storage.deleted_paths
      assert_nil repo.soft_deleted
    end
  end
end
