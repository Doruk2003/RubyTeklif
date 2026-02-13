class OffersPolicy < ApplicationPolicy
  def access?
    role_in?(Roles::ADMIN, Roles::SALES)
  end
end
