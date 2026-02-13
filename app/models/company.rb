class Company
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :id, :string
  attribute :name, :string
  attribute :tax_number, :string
  attribute :tax_office, :string
  attribute :authorized_person, :string
  attribute :phone, :string
  attribute :email, :string
  attribute :address, :string
  attribute :active, :boolean, default: true
  attribute :deleted_at, :datetime
  attribute :offers_count, :integer, default: 0

  def persisted?
    id.present?
  end
end
