require "test_helper"

module Admin
  module Users
    class ExportFormTest < ActiveSupport::TestCase
      test "accepts valid filters" do
        form = Admin::Users::ExportForm.new(
          q: "ali",
          role: Roles::MANAGER,
          active: "true"
        )

        assert form.valid?
        assert_equal(
          { q: "ali", role: Roles::MANAGER, active: "true" },
          form.to_h
        )
      end

      test "rejects invalid role" do
        form = Admin::Users::ExportForm.new(
          q: "ali",
          role: "bad-role",
          active: "true"
        )

        assert_equal false, form.valid?
        assert_includes form.errors[:role], "is not included in the list"
      end

      test "rejects invalid active filter" do
        form = Admin::Users::ExportForm.new(
          q: "ali",
          role: Roles::MANAGER,
          active: "yes"
        )

        assert_equal false, form.valid?
        assert_includes form.errors[:active], "is not included in the list"
      end
    end
  end
end
