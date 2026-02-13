module Categories
  class UpsertForm
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :code, :string
    attribute :name, :string
    attribute :active

    validates :code, presence: true, length: { in: 2..60 }, format: { with: /\A[a-z0-9_]+\z/ }
    validates :name, presence: true, length: { maximum: 100 }

    def normalized_attributes
      {
        code: code.to_s.strip.downcase,
        name: name.to_s.strip,
        active: normalize_active(active)
      }
    end

    private

    def normalize_active(value)
      value.to_s.in?(%w[1 true on])
    end
  end
end
