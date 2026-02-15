require "test_helper"

class RolesTest < ActiveSupport::TestCase
  test "assignable roles include main four roles" do
    assert_equal [Roles::ADMIN, Roles::MANAGER, Roles::OPERATOR, Roles::VIEWER], Roles::ASSIGNABLE_ROLES
  end

  test "catalog manage allows admin manager operator and legacy sales" do
    assert_equal true, Roles.catalog_manage?(Roles::ADMIN)
    assert_equal true, Roles.catalog_manage?(Roles::MANAGER)
    assert_equal true, Roles.catalog_manage?(Roles::OPERATOR)
    assert_equal true, Roles.catalog_manage?(Roles::SALES)
    assert_equal false, Roles.catalog_manage?(Roles::VIEWER)
    assert_equal false, Roles.catalog_manage?(Roles::FINANCE)
  end

  test "finance manage allows admin manager and legacy finance only" do
    assert_equal true, Roles.finance_manage?(Roles::ADMIN)
    assert_equal true, Roles.finance_manage?(Roles::MANAGER)
    assert_equal true, Roles.finance_manage?(Roles::FINANCE)
    assert_equal false, Roles.finance_manage?(Roles::OPERATOR)
    assert_equal false, Roles.finance_manage?(Roles::VIEWER)
    assert_equal false, Roles.finance_manage?(Roles::SALES)
  end
end
