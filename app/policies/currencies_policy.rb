class CurrenciesPolicy < ApplicationPolicy
  def access?
    role_in?(Roles::ADMIN, Roles::FINANCE)
  end
end
