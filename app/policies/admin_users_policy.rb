class AdminUsersPolicy < ApplicationPolicy
  def access?
    role_in?(Roles::ADMIN)
  end
end
