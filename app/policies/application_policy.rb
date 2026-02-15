class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record = nil)
    @user = user
    @record = record
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
