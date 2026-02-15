require "csv"
require "fileutils"

module Admin
  module Users
    class ExportCsvJob < ApplicationJob
      queue_as :reports

      retry_on ServiceErrors::System, wait: 20.seconds, attempts: 3

      def perform(token, actor_id, filters = {})
        filters = (filters || {}).to_h
        client = Supabase::Client.new(role: :service)
        query = Admin::Users::IndexQuery.new(client: client)
        rows = query.export_rows(params: filters, max_rows: 5_000)

        export_dir = Rails.root.join("tmp", "exports", "users")
        FileUtils.mkdir_p(export_dir)
        file_path = export_dir.join("admin_users_#{token}.csv")

        CSV.open(file_path, "wb", headers: true) do |csv|
          csv << %w[email role active]
          rows.each do |row|
            csv << [
              row["email"].to_s,
              row["role"].to_s,
              row["active"].to_s
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
      rescue StandardError => error
        Rails.cache.write(
          status_cache_key(token),
          { status: "failed", actor_id: actor_id, error: error.message.to_s.first(200) },
          expires_in: 30.minutes
        )
        raise
      end

      private

      def status_cache_key(token)
        "admin/users/export/#{token}"
      end
    end
  end
end
