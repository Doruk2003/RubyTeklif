require "test_helper"

module Admin
  module ActivityLogs
    class ExportCsvJobTest < ActiveSupport::TestCase
      class FakeIndexQuery
        def export_rows(params:, max_rows: 5000)
          [
            {
              "created_at" => "2026-02-15T10:00:00Z",
              "action" => "users.role_change",
              "actor_id" => "usr-1",
              "target_id" => "usr-2",
              "target_type" => "user",
              "metadata" => "{\"role\":\"manager\"}"
            }
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
        token = "tok123"
        actor_id = "usr-1"
        cache_key = "admin/activity_logs/export/#{token}"
        test_cache = ActiveSupport::Cache::MemoryStore.new
        original_cache_method = Rails.method(:cache)

        Rails.singleton_class.send(:define_method, :cache) { test_cache }
        begin
          with_stubbed_constructor(Supabase::Client, Object.new) do
            with_stubbed_constructor(Admin::ActivityLogs::IndexQuery, FakeIndexQuery.new) do
              Admin::ActivityLogs::ExportCsvJob.perform_now(token, actor_id, {})
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
