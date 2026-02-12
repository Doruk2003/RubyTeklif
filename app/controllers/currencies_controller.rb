require "bigdecimal"

class CurrenciesController < ApplicationController
  before_action :authorize_currencies!
  def index
    data = client.get("currencies?select=id,code,name,symbol,rate_to_try,active&order=code.asc")
    @currencies = data.is_a?(Array) ? data : []
  rescue Supabase::Client::ConfigurationError
    @currencies = []
  end

  def new
    @currency = {}
  end

  def create
    payload = {}
    payload = currency_params

    payload[:user_id] = service_user_id
    payload[:code] = payload[:code].to_s.upcase.strip
    payload[:rate_to_try] = normalize_number(payload[:rate_to_try])
    payload[:active] = normalize_active(payload[:active])

    created = client.post("currencies", body: payload, headers: { "Prefer" => "return=representation" })
    currency_id = extract_id(created)

    if currency_id
      redirect_to currencies_path, notice: "Kur kaydi olusturuldu."
    else
      raise "Kur ID alinmadi."
    end
  rescue StandardError => e
    flash.now[:alert] = "Kur kaydi olusturulamadi: #{e.message}"
    @currency = payload || {}
    render :new, status: :unprocessable_entity
  end

  def edit
    data = client.get("currencies?id=eq.#{params[:id]}&select=id,code,name,symbol,rate_to_try,active")
    @currency = data.is_a?(Array) ? data.first : nil
  rescue Supabase::Client::ConfigurationError
    @currency = nil
  end

  def update
    payload = {}
    payload = currency_params

    payload[:code] = payload[:code].to_s.upcase.strip
    payload[:rate_to_try] = normalize_number(payload[:rate_to_try])
    payload[:active] = normalize_active(payload[:active])

    client.patch("currencies?id=eq.#{params[:id]}", body: payload, headers: { "Prefer" => "return=representation" })
    redirect_to currencies_path, notice: "Kur guncellendi."
  rescue StandardError => e
    flash.now[:alert] = "Kur guncellenemedi: #{e.message}"
    @currency = payload.merge("id" => params[:id])
    render :edit, status: :unprocessable_entity
  end

  def destroy
    client.delete("currencies?id=eq.#{params[:id]}", headers: { "Prefer" => "return=minimal" })
    redirect_to currencies_path, notice: "Kur silindi."
  rescue StandardError => e
    redirect_to currencies_path, alert: "Kur silinemedi: #{e.message}"
  end

  private

  def client
    @client ||= Supabase::Client.new(role: :service)
  end

  def currency_params
    params.require(:currency).permit(:code, :name, :symbol, :rate_to_try, :active)
  end

  def normalize_active(value)
    value.to_s.in?(%w[1 true on])
  end

  def normalize_number(value)
    decimal(value).to_f
  end

  def service_user_id
    ENV.fetch("SUPABASE_SERVICE_USER_ID")
  end

  def extract_id(response)
    return response.first["id"].to_s if response.is_a?(Array) && response.first.is_a?(Hash)
    return response["id"].to_s if response.is_a?(Hash)

    nil
  end

  def decimal(value)
    return BigDecimal("0") if value.nil?

    BigDecimal(value.to_s)
  rescue ArgumentError
    BigDecimal("0")
  end

  def authorize_currencies!
    require_role!(Roles::ADMIN, Roles::FINANCE)
  end
end
