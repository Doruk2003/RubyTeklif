class AdminActivityLogsPolicy < ApplicationPolicy
  def access?
    role_in?(Roles::ADMIN)
  end
end
