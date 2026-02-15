require "csv"
require "fileutils"

module Admin
  module ActivityLogs
    class ExportCsvJob < ApplicationJob
      queue_as :reports

      retry_on ServiceErrors::System, wait: 20.seconds, attempts: 3

      def perform(token, actor_id, filters = {})
        filters = (filters || {}).to_h
        client = Supabase::Client.new(role: :service)
        query = Admin::ActivityLogs::IndexQuery.new(client: client)
        rows = query.export_rows(params: filters, max_rows: 5_000)

        export_dir = Rails.root.join("tmp", "exports", "activity_logs")
        FileUtils.mkdir_p(export_dir)
        file_path = export_dir.join("activity_logs_#{token}.csv")

        CSV.open(file_path, "wb", headers: true) do |csv|
          csv << %w[created_at action actor_id target_id target_type metadata]
          rows.each do |row|
            csv << [
              row["created_at"].to_s,
              row["action"].to_s,
              row["actor_id"].to_s,
              row["target_id"].to_s,
              row["target_type"].to_s,
              row["metadata"].to_s
            ]
          end
        end

        Rails.cache.write(
          status_cache_key(token),
          {
            status: "ready",
            actor_id: actor_id,
            file_path: file_path.to_s,
            generated_at: Time.current.iso8601
          },
          expires_in: 30.minutes
        )
      rescue StandardError => e
        Rails.cache.write(
          status_cache_key(token),
          { status: "failed", actor_id: actor_id, error: e.message.to_s.first(200) },
          expires_in: 30.minutes
        )
        raise
      end

      private

      def status_cache_key(token)
        "admin/activity_logs/export/#{token}"
      end
    end
  end
end
