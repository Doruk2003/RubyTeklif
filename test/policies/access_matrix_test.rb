require "test_helper"

class AccessMatrixTest < ActiveSupport::TestCase
  POLICY_EXPECTATIONS = {
    AdminUsersPolicy => {
      admin: true,
      manager: false,
      operator: false,
      viewer: false
    },
    AdminActivityLogsPolicy => {
      admin: true,
      manager: false,
      operator: false,
      viewer: false
    },
    CompaniesPolicy => {
      admin: true,
      manager: true,
      operator: true,
      viewer: false
    },
    CategoriesPolicy => {
      admin: true,
      manager: true,
      operator: true,
      viewer: false
    },
    ProductsPolicy => {
      admin: true,
      manager: true,
      operator: true,
      viewer: false
    },
    OffersPolicy => {
      admin: true,
      manager: true,
      operator: true,
      viewer: false
    },
    CurrenciesPolicy => {
      admin: true,
      manager: true,
      operator: false,
      viewer: false
    }
  }.freeze

  test "policy access matrix for main roles" do
    POLICY_EXPECTATIONS.each do |policy_class, role_map|
      role_map.each do |role, expected|
        user = CurrentUser.new(role: role, id: "#{role}-1")
        policy = policy_class.new(user)
        assert_equal expected, policy.access?, "#{policy_class} expected #{expected} for #{role}"
      end
    end
  end

  test "all policies deny access for nil user" do
    POLICY_EXPECTATIONS.each_key do |policy_class|
      assert_equal false, policy_class.new(nil).access?, "#{policy_class} should deny nil user"
    end
  end
end
