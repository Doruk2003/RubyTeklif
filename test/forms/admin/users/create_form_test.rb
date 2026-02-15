require "test_helper"

module Admin
  module Users
    class CreateFormTest < ActiveSupport::TestCase
      test "is valid with assignable roles" do
        form = Admin::Users::CreateForm.new(
          email: "user@example.com",
          password: "Password12",
          role: Roles::MANAGER
        )

        assert form.valid?
      end

      test "rejects legacy roles" do
        form = Admin::Users::CreateForm.new(
          email: "user@example.com",
          password: "Password12",
          role: Roles::SALES
        )

        assert_equal false, form.valid?
        assert_includes form.errors[:role], "is not included in the list"
      end
    end
  end
end
