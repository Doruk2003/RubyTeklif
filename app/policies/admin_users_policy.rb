class AdminUsersPolicy < ApplicationPolicy
  def access?
    Roles.admin?(user&.role)
  end
end
