module Admin
  module Users
    # Validates and normalizes admin users export filters.
    class ExportForm
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :q, :string
      attribute :role, :string
      attribute :active, :string

      validates :role, inclusion: { in: Roles::ACCEPTED_ROLES }, allow_blank: true
      validates :active, inclusion: { in: %w[true false] }, allow_blank: true

      def to_h
        {
          q: q.to_s.presence,
          role: role.to_s.presence,
          active: active.to_s.presence
        }.compact
      end
    end
  end
end
