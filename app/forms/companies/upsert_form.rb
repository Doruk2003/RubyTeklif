module Companies
  class UpsertForm
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :name, :string
    attribute :tax_number, :string
    attribute :tax_office, :string
    attribute :authorized_person, :string
    attribute :phone, :string
    attribute :email, :string
    attribute :address, :string
    attribute :active

    validates :name, presence: true, length: { maximum: 150 }
    validates :tax_number, presence: true, length: { in: 8..20 }
    validates :tax_office, length: { maximum: 120 }, allow_blank: true
    validates :authorized_person, length: { maximum: 120 }, allow_blank: true
    validates :phone, length: { maximum: 40 }, allow_blank: true
    validates :address, length: { maximum: 500 }, allow_blank: true
    validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

    def normalized_attributes
      {
        name: name.to_s.strip,
        tax_number: tax_number.to_s.strip,
        tax_office: tax_office.to_s.strip,
        authorized_person: authorized_person.to_s.strip,
        phone: phone.to_s.strip,
        email: email.to_s.strip,
        address: address.to_s.strip,
        active: normalize_active(active)
      }
    end

    private

    def normalize_active(value)
      value.to_s.in?(%w[1 true on])
    end
  end
end

