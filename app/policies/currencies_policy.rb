class CurrenciesPolicy < ApplicationPolicy
  def access?
    Roles.finance_manage?(user&.role)
  end
end
