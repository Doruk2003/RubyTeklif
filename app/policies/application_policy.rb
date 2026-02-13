class ApplicationPolicy
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def access?
    false
  end

  private

  def role_in?(*roles)
    return false if user.nil?

    roles.map(&:to_s).include?(user.role.to_s)
  end
end
