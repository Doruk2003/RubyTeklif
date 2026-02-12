class CompaniesController < ApplicationController
  def index
    @companies = apply_filters(load_companies)
  rescue Supabase::Client::ConfigurationError
    @companies = []
    flash.now[:alert] = "Supabase ayarlari eksik oldugu icin musteriler yuklenemedi."
  end

  def show
    @company = find_company
    if @company.nil?
      redirect_to companies_path, alert: "Musteri bulunamadi."
      return
    end

    @offers = []
  end

  def new
    @company = Company.new(active: true)
  end

  def create
    form_payload = company_params
    payload = form_payload.merge(
      user_id: service_user_id,
      active: normalize_active(form_payload[:active])
    )

    created = client.post("companies", body: payload, headers: { "Prefer" => "return=representation" })
    if response_has_error?(created)
      if duplicate_tax_number_error?(created)
        flash.now[:alert] = "Bu vergi numarasi zaten kayitli."
        @company = Company.new(form_payload || {})
        render :new, status: :unprocessable_entity
        return
      end

      raise response_error(created, fallback: "Musteri olusturulamadi.")
    end

    company_id = extract_id(created)
    company_id = find_company_id_by_tax_number_for_user(payload[:tax_number], payload[:user_id]) if company_id.blank?

    if company_id.present? && company_exists?(company_id)
      company_name = payload[:name].to_s.strip
      notice_message = company_name.present? ? "#{company_name} musterisi olusturuldu." : "Musteri olusturuldu."
      redirect_to companies_path, notice: notice_message
    else
      raise "Insert yaniti alindi ancak kayit dogrulanamadi. Supabase proje ayarlarini kontrol edin."
    end
  rescue StandardError => e
    flash.now[:alert] = "Musteri olusturulamadi: #{e.message}"
    @company = Company.new(form_payload || {})
    render :new, status: :unprocessable_entity
  end

  def edit
    @company = find_company
    if @company.nil?
      redirect_to companies_path, alert: "Musteri bulunamadi."
      return
    end
  end

  def update
    payload = {}
    payload = company_params
    payload[:active] = normalize_active(payload[:active])

    updated = client.patch("companies?id=eq.#{params[:id]}", body: payload, headers: { "Prefer" => "return=representation" })
    raise response_error(updated, fallback: "Musteri guncellenemedi.") if response_has_error?(updated)
    if updated.is_a?(Array) && updated.empty?
      raise "Musteri bulunamadi veya guncellenemedi."
    end

    redirect_to company_path(params[:id]), notice: "Musteri guncellendi."
  rescue StandardError => e
    flash.now[:alert] = "Musteri guncellenemedi: #{e.message}"
    @company = Company.new(payload.merge(id: params[:id]))
    render :edit, status: :unprocessable_entity
  end

  def destroy
    deleted = client.delete("companies?id=eq.#{params[:id]}", headers: { "Prefer" => "return=minimal" })
    raise response_error(deleted, fallback: "Musteri silinemedi.") if response_has_error?(deleted)

    redirect_to companies_path, notice: "Musteri silindi."
  rescue StandardError => e
    redirect_to companies_path, alert: "Musteri silinemedi: #{e.message}"
  end

  private

  def company_params
    params.require(:company).permit(:name, :tax_number, :tax_office, :authorized_person, :phone, :email, :address, :active)
  end

  def client
    @client ||= Supabase::Client.new(role: :service)
  end

  def load_companies
    data = client.get("companies?select=id,name,tax_number,tax_office,authorized_person,phone,email,address,active&order=created_at.desc")
    rows = data.is_a?(Array) ? data : []
    offer_counts = load_offer_counts

    rows.map do |row|
      build_company(row, offers_count: offer_counts[row["id"]].to_i)
    end
  end

  def load_offer_counts
    data = client.get("offers?select=company_id")
    rows = data.is_a?(Array) ? data : []

    rows.each_with_object(Hash.new(0)) do |row, counts|
      company_id = row["company_id"].to_s
      counts[company_id] += 1 if company_id.present?
    end
  rescue StandardError
    Hash.new(0)
  end

  def apply_filters(companies)
    result = companies

    if params[:q].present?
      q = params[:q].to_s.downcase
      result = result.select do |company|
        company.name.to_s.downcase.include?(q) ||
          company.authorized_person.to_s.downcase.include?(q) ||
          company.email.to_s.downcase.include?(q)
      end
    end

    if params[:tax_number].present?
      tax = params[:tax_number].to_s.downcase
      result = result.select { |company| company.tax_number.to_s.downcase.include?(tax) }
    end

    if params[:active].present?
      active = params[:active].to_s == "1"
      result = result.select { |company| company.active == active }
    end

    if params[:has_offers].present?
      has_offers = params[:has_offers].to_s == "1"
      result = result.select do |company|
        has_offers ? company.offers_count.to_i.positive? : company.offers_count.to_i.zero?
      end
    end

    result
  end

  def find_company
    data = client.get("companies?id=eq.#{params[:id]}&select=id,name,tax_number,tax_office,authorized_person,phone,email,address,active")
    row = data.is_a?(Array) ? data.first : nil
    return nil unless row.is_a?(Hash)

    build_company(row)
  rescue Supabase::Client::ConfigurationError
    nil
  end

  def build_company(row, offers_count: 0)
    Company.new(
      id: row["id"],
      name: row["name"],
      tax_number: row["tax_number"],
      tax_office: row["tax_office"],
      authorized_person: row["authorized_person"],
      phone: row["phone"],
      email: row["email"],
      address: row["address"],
      active: row.key?("active") ? row["active"] : true,
      offers_count: offers_count
    )
  end

  def normalize_active(value)
    value.to_s.in?(%w[1 true on])
  end

  def service_user_id
    ENV.fetch("SUPABASE_SERVICE_USER_ID")
  end

  def extract_id(response)
    return response.first["id"].to_s if response.is_a?(Array) && response.first.is_a?(Hash)
    return response["id"].to_s if response.is_a?(Hash)

    nil
  end

  def response_has_error?(response)
    response.is_a?(Hash) && (response["message"].present? || response["error"].present?)
  end

  def response_error(response, fallback:)
    return fallback unless response.is_a?(Hash)

    if duplicate_tax_number_error?(response)
      return "Bu vergi numarasi zaten kayitli."
    end

    parts = [response["message"], response["details"], response["hint"], response["code"]].compact.reject(&:blank?)
    return fallback if parts.empty?

    parts.join(" | ")
  end

  def duplicate_tax_number_error?(response)
    return false unless response.is_a?(Hash)

    return false unless response["code"].to_s == "23505"

    message = response["message"].to_s.downcase
    message.include?("companies_tax_number_idx") || message.include?("companies_user_tax_number_idx")
  end

  def company_exists?(company_id)
    data = client.get("companies?id=eq.#{company_id}&select=id&limit=1")
    data.is_a?(Array) && data.first.is_a?(Hash) && data.first["id"].present?
  rescue StandardError
    false
  end

  def find_company_id_by_tax_number_for_user(tax_number, user_id)
    return nil if tax_number.blank? || user_id.blank?

    data = client.get("companies?user_id=eq.#{user_id}&tax_number=eq.#{tax_number}&order=created_at.desc&select=id&limit=1")
    return nil unless data.is_a?(Array) && data.first.is_a?(Hash)

    data.first["id"].to_s.presence
  rescue StandardError
    nil
  end
end
