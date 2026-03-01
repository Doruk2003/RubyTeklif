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
  attribute :description, :string
  attribute :city, :string
  attribute :country, :string
  attribute :active, :boolean, default: true
  attribute :deleted_at, :datetime
  attribute :offers_count, :integer, default: 0
  attribute :total_offers_count, :integer, default: 0
  attribute :approved_offers_count, :integer, default: 0
  attribute :total_offer_amount, :decimal, default: 0
  attribute :approved_offer_amount, :decimal, default: 0
  attribute :total_sales_amount, :decimal, default: 0
  attribute :total_order_amount, :decimal, default: 0
  attribute :pending_order_amount, :decimal, default: 0

  def persisted?
    id.present?
  end
end
