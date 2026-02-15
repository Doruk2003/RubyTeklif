require "test_helper"

class AdminControllerFormBoundaryTest < ActiveSupport::TestCase
  test "admin users controller uses form layer for mutable input" do
    source = File.read(Rails.root.join("app/controllers/admin/users_controller.rb"))

    assert_includes source, "Admin::Users::CreateForm.new("
    assert_includes source, "Admin::Users::UpdateRoleForm.new("
    assert_includes source, "Admin::Users::ExportForm.new("
  end

  test "admin activity logs controller uses export form layer" do
    source = File.read(Rails.root.join("app/controllers/admin/activity_logs_controller.rb"))

    assert_includes source, "Admin::ActivityLogs::ExportForm.new("
  end
end
