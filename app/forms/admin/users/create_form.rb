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
      validates :role, inclusion: { in: [Roles::ADMIN, Roles::SALES, Roles::FINANCE, Roles::HR] }

      def role
        super.to_s.presence || Roles::ADMIN
      end

      def email
        super.to_s.strip
      end
    end
  end
end

