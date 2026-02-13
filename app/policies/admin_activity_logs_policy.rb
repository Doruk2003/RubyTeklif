class AdminActivityLogsPolicy < ApplicationPolicy
  def access?
    Roles.admin?(user&.role)
  end
end
