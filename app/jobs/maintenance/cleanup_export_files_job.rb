module Maintenance
  class CleanupExportFilesJob < ApplicationJob
    queue_as :maintenance

    EXPORT_DIRS = [
      Rails.root.join("tmp", "exports", "activity_logs"),
      Rails.root.join("tmp", "exports", "users")
    ].freeze

    def perform(older_than_minutes: 60)
      threshold_time = Time.current - older_than_minutes.to_i.minutes

      EXPORT_DIRS.each do |dir|
        next unless Dir.exist?(dir)

        Dir.glob(File.join(dir, "*.csv")).each do |file_path|
          next unless File.file?(file_path)
          next unless File.mtime(file_path) < threshold_time

          File.delete(file_path)
        rescue StandardError => error
          Observability::ErrorReporter.report(
            error,
            severity: :warn,
            context: { source: "jobs/maintenance/cleanup_export_files", file_path: file_path }
          )
        end
      end
    end
  end
end
