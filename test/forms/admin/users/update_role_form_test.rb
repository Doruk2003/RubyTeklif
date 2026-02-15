require "test_helper"

module Admin
  module Users
    class UpdateRoleFormTest < ActiveSupport::TestCase
      test "is valid for assignable role" do
        form = Admin::Users::UpdateRoleForm.new(role: Roles::OPERATOR)

        assert form.valid?
      end

      test "rejects legacy role" do
        form = Admin::Users::UpdateRoleForm.new(role: Roles::SALES)

        assert_equal false, form.valid?
        assert_includes form.errors[:role], "is not included in the list"
      end
    end
  end
end
