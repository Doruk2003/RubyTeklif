class CurrentUser
  attr_reader :id, :role, :name

  def initialize(role:, id: nil, name: nil)
    @role = role.to_s
    @id = id
    @name = name
  end
end
