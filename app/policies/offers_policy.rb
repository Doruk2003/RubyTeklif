class OffersPolicy < ApplicationPolicy
  def access?
    Roles.catalog_manage?(user&.role)
  end
end
