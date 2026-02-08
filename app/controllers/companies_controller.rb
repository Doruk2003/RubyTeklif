class CompaniesController < ApplicationController
  def index
    @companies = apply_filters(seed_companies)
  end

  def show
    @company = find_company
    @offers = []
  end

  def new
    @company = Company.new
  end

  def create
    @company = Company.new(company_params)
    redirect_to companies_path, notice: "Müşteri oluşturuldu (demo)."
  end

  def edit
    @company = find_company
  end

  def update
    @company = Company.new(company_params.merge(id: params[:id]))
    redirect_to company_path(@company), notice: "Müşteri güncellendi (demo)."
  end

  def destroy
    redirect_to companies_path, notice: "Müşteri silindi (demo)."
  end

  private

  def company_params
    params.require(:company).permit(:name, :tax_number, :authorized_person, :phone, :address)
  end

  def seed_companies
    [
      Company.new(
        id: "1",
        name: "Acme Ltd.",
        tax_number: "1234567890",
        authorized_person: "Ahmet Yılmaz",
        phone: "0555 123 45 67",
        address: "İstanbul",
        offers_count: 2
      ),
      Company.new(
        id: "2",
        name: "Beta A.Ş.",
        tax_number: "9876543210",
        authorized_person: "Zeynep Kaya",
        phone: "0532 987 65 43",
        address: "Ankara",
        offers_count: 0
      )
    ]
  end

  def apply_filters(companies)
    result = companies

    if params[:q].present?
      q = params[:q].to_s.downcase
      result = result.select do |c|
        c.name.to_s.downcase.include?(q) ||
          c.authorized_person.to_s.downcase.include?(q)
      end
    end

    if params[:tax_number].present?
      tax = params[:tax_number].to_s.downcase
      result = result.select { |c| c.tax_number.to_s.downcase.include?(tax) }
    end

    if params[:has_offers].present?
      has_offers = params[:has_offers].to_s == "1"
      result = result.select do |c|
        has_offers ? c.offers_count.to_i.positive? : c.offers_count.to_i.zero?
      end
    end

    result
  end

  def find_company
    seed_companies.find { |c| c.id.to_s == params[:id].to_s } || seed_companies.first
  end
end
