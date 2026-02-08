class Company
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :id, :string
  attribute :name, :string
  attribute :tax_number, :string
  attribute :authorized_person, :string
  attribute :phone, :string
  attribute :address, :string
  attribute :offers_count, :integer, default: 0

  def persisted?
    id.present?
  end
end
