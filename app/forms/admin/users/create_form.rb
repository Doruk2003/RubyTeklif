module Admin
  module Users
    class CreateForm
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :email, :string
      attribute :password, :string
      attribute :role, :string

      validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
      validates :password, presence: true, length: { minimum: 8, maximum: 128 }
      validates :role, inclusion: { in: Roles::ASSIGNABLE_ROLES }

      def role
        super.to_s.presence || Roles::ADMIN
      end

      def email
        super.to_s.strip
      end

      def to_h
        {
          email: email,
          password: password.to_s,
          role: role
        }
      end
    end
  end
end
