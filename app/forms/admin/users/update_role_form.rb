module Admin
  module Users
    # Validates role changes performed by admin users.
    class UpdateRoleForm
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :role, :string

      validates :role, inclusion: { in: Roles::ASSIGNABLE_ROLES }
    end
  end
end
