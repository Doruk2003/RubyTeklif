require "test_helper"
require "fileutils"

module Maintenance
  class CleanupExportFilesJobTest < ActiveSupport::TestCase
    test "removes only old export files" do
      activity_dir = Rails.root.join("tmp", "exports", "activity_logs")
      users_dir = Rails.root.join("tmp", "exports", "users")
      FileUtils.mkdir_p(activity_dir)
      FileUtils.mkdir_p(users_dir)

      old_file = activity_dir.join("old_export.csv")
      fresh_file = users_dir.join("fresh_export.csv")

      File.write(old_file, "old")
      File.write(fresh_file, "fresh")
      File.utime(3.hours.ago.to_time, 3.hours.ago.to_time, old_file)
      File.utime(10.minutes.ago.to_time, 10.minutes.ago.to_time, fresh_file)

      Maintenance::CleanupExportFilesJob.perform_now(older_than_minutes: 120)

      assert_not File.exist?(old_file), "old export should be deleted"
      assert File.exist?(fresh_file), "fresh export should be preserved"
    ensure
      File.delete(old_file) if defined?(old_file) && File.exist?(old_file)
      File.delete(fresh_file) if defined?(fresh_file) && File.exist?(fresh_file)
    end
  end
end
