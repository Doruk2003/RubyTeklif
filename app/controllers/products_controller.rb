require "bigdecimal"

class ProductsController < ApplicationController
  ALLOWED_TYPES = %w[product demonte service].freeze
  before_action :authorize_products!

  def index
    data = client.get("products?select=id,name,price,vat_rate,item_type,active,companies(name)&order=created_at.desc")
    @products = data.is_a?(Array) ? data : []
  rescue Supabase::Client::ConfigurationError
    @products = []
  end

  def show
    data = client.get("products?id=eq.#{params[:id]}&select=id,company_id,name,price,vat_rate,item_type,active,companies(name)")
    @product = data.is_a?(Array) ? data.first : nil
  rescue Supabase::Client::ConfigurationError
    @product = nil
  end

  def new
    @product = {}
    @companies = load_companies
  end

  def edit
    data = client.get("products?id=eq.#{params[:id]}&select=id,company_id,name,price,vat_rate,item_type,active")
    @product = data.is_a?(Array) ? data.first : nil
    @companies = load_companies
  rescue Supabase::Client::ConfigurationError
    @product = nil
    @companies = []
  end

  def create
    payload = {}
    payload = product_params

    payload[:user_id] = service_user_id
    payload[:item_type] = normalize_item_type(payload[:item_type])
    payload[:price] = normalize_number(payload[:price])
    payload[:vat_rate] = normalize_number(payload[:vat_rate])
    payload[:active] = normalize_active(payload[:active])

    created = client.post("products", body: payload, headers: { "Prefer" => "return=representation" })
    product_id = extract_id(created)

    if product_id
      redirect_to product_path(product_id), notice: "Ürün oluşturuldu."
    else
      raise "Ürün ID alınamadı."
    end
  rescue StandardError => e
    flash.now[:alert] = "Ürün oluşturulamadı: #{e.message}"
    @product = payload || {}
    @companies = load_companies
    render :new, status: :unprocessable_entity
  end

  def update
    payload = {}
    payload = product_params

    payload[:item_type] = normalize_item_type(payload[:item_type])
    payload[:price] = normalize_number(payload[:price])
    payload[:vat_rate] = normalize_number(payload[:vat_rate])
    payload[:active] = normalize_active(payload[:active])

    updated = client.patch("products?id=eq.#{params[:id]}", body: payload, headers: { "Prefer" => "return=representation" })
    product_id = extract_id(updated) || params[:id]

    redirect_to product_path(product_id), notice: "Ürün güncellendi."
  rescue StandardError => e
    flash.now[:alert] = "Ürün güncellenemedi: #{e.message}"
    @product = payload.merge("id" => params[:id])
    @companies = load_companies
    render :edit, status: :unprocessable_entity
  end

  def destroy
    client.delete("products?id=eq.#{params[:id]}", headers: { "Prefer" => "return=minimal" })
    redirect_to products_path, notice: "Ürün silindi."
  rescue StandardError => e
    redirect_to products_path, alert: "Ürün silinemedi: #{e.message}"
  end

  private

  def client
    @client ||= Supabase::Client.new(role: :service)
  end

  def product_params
    params.require(:product).permit(:company_id, :name, :price, :vat_rate, :item_type, :active)
  end

  def load_companies
    data = client.get("companies?select=id,name&order=name.asc")
    data.is_a?(Array) ? data : []
  rescue Supabase::Client::ConfigurationError
    []
  end

  def normalize_item_type(value)
    type = value.to_s.downcase
    ALLOWED_TYPES.include?(type) ? type : "product"
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

  def authorize_products!
    require_role!(Roles::ADMIN, Roles::SALES)
  end
end
