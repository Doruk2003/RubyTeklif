require "test_helper"

module Admin
  module Users
    class ExportCsvJobTest < ActiveSupport::TestCase
      class FakeIndexQuery
        def export_rows(params:, max_rows: 5000)
          [
            { "email" => "user1@example.com", "role" => "admin", "active" => true },
            { "email" => "user2@example.com", "role" => "manager", "active" => false }
          ]
        end
      end

      private def with_stubbed_constructor(klass, instance)
        original_new = klass.method(:new)
        klass.singleton_class.send(:define_method, :new) do |*args, **kwargs, &blk|
          instance
        end
        yield
      ensure
        klass.singleton_class.send(:define_method, :new) do |*args, **kwargs, &blk|
          original_new.call(*args, **kwargs, &blk)
        end
      end

      test "writes csv and marks export as ready" do
        token = "usrtok123"
        actor_id = "usr-admin"
        cache_key = "admin/users/export/#{token}"
        test_cache = ActiveSupport::Cache::MemoryStore.new
        original_cache_method = Rails.method(:cache)

        Rails.singleton_class.send(:define_method, :cache) { test_cache }
        begin
          with_stubbed_constructor(Supabase::Client, Object.new) do
            with_stubbed_constructor(Admin::Users::IndexQuery, FakeIndexQuery.new) do
              Admin::Users::ExportCsvJob.perform_now(token, actor_id, {})
            end
          end
        ensure
          Rails.singleton_class.send(:define_method, :cache) { original_cache_method.call }
        end

        state = test_cache.read(cache_key)
        assert_equal "ready", state[:status]
        assert_equal actor_id, state[:actor_id]
        assert File.exist?(state[:file_path])
      ensure
        if state && state[:file_path].present? && File.exist?(state[:file_path])
          File.delete(state[:file_path])
        end
      end
    end
  end
end
