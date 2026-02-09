require "bigdecimal"

class OffersController < ApplicationController
  ALLOWED_STATUSES = %w[taslak gonderildi beklemede onaylandi reddedildi].freeze

  def index
    data = client.get("offers?select=id,offer_number,offer_date,gross_total,status,companies(name)&order=offer_date.desc")
    @offers = data.is_a?(Array) ? data : []
  rescue Supabase::Client::ConfigurationError
    @offers = []
  end

  def show
    data = client.get("offers?id=eq.#{params[:id]}&select=id,offer_number,offer_date,net_total,vat_total,gross_total,status,companies(name),offer_items(id,description,quantity,unit_price,line_total,products(name,vat_rate))")
    @offer = data.is_a?(Array) ? data.first : nil
  rescue Supabase::Client::ConfigurationError
    @offer = nil
  end

  def new
    @offer = {}
    @items = []
  end

  def create
    payload = {}
    payload = offer_params
    items = normalize_items(payload.delete(:items))
    product_map = load_products(items.map { |i| i[:product_id] })

    items = items.map { |item| enrich_item(item, product_map) }
    totals = calculate_totals(items)

    offer_body = payload.merge(
      status: normalize_status(payload[:status]),
      user_id: service_user_id,
      net_total: totals[:net_total],
      vat_total: totals[:vat_total],
      gross_total: totals[:gross_total]
    )

    created = client.post("offers", body: offer_body, headers: { "Prefer" => "return=representation" })
    offer_id = extract_id(created)

    if offer_id
      insert_items(offer_id, items)
      redirect_to offer_path(offer_id), notice: "Teklif oluþturuldu."
    else
      raise "Teklif ID alýnamadý."
    end
  rescue StandardError => e
    flash.now[:alert] = "Teklif oluþturulamadý: #{e.message}"
    @offer = payload || {}
    @items = items || []
    render :new, status: :unprocessable_entity
  end

  private

  def client
    @client ||= Supabase::Client.new(role: :service)
  end

  def offer_params
    params.require(:offer).permit(
      :company_id,
      :offer_number,
      :offer_date,
      :status,
      items: %i[product_id description quantity unit_price]
    )
  end

  def normalize_items(raw_items)
    Array(raw_items).map do |item|
      {
        product_id: item[:product_id].to_s,
        description: item[:description].to_s,
        quantity: decimal(item[:quantity]),
        unit_price: decimal(item[:unit_price])
      }
    end.reject { |i| i[:product_id].empty? }
  end

  def load_products(product_ids)
    ids = product_ids.compact.uniq
    return {} if ids.empty?

    encoded_ids = ids.join(",")
    data = client.get("products?select=id,name,vat_rate&id=in.(#{encoded_ids})")
    return {} unless data.is_a?(Array)

    data.each_with_object({}) do |row, acc|
      acc[row["id"].to_s] = {
        name: row["name"].to_s,
        vat_rate: decimal(row["vat_rate"])
      }
    end
  end

  def enrich_item(item, product_map)
    product = product_map[item[:product_id]] || {}
    quantity = item[:quantity]
    unit_price = item[:unit_price]
    line_total = quantity * unit_price

    {
      product_id: item[:product_id],
      description: item[:description].presence || product[:name].to_s,
      quantity: quantity,
      unit_price: unit_price,
      line_total: line_total,
      vat_rate: product[:vat_rate] || decimal(0)
    }
  end

  def calculate_totals(items)
    net_total = decimal(0)
    vat_total = decimal(0)

    items.each do |item|
      net_total += item[:line_total]
      vat_total += item[:line_total] * item[:vat_rate] / decimal(100)
    end

    gross_total = net_total + vat_total

    {
      net_total: net_total,
      vat_total: vat_total,
      gross_total: gross_total
    }
  end

  def insert_items(offer_id, items)
    return if items.empty?

    payload = items.map do |item|
      {
        user_id: service_user_id,
        offer_id: offer_id,
        product_id: item[:product_id],
        description: item[:description],
        quantity: item[:quantity],
        unit_price: item[:unit_price],
        line_total: item[:line_total]
      }
    end

    client.post("offer_items", body: payload, headers: { "Prefer" => "return=minimal" })
  end

  def normalize_status(value)
    status = value.to_s.downcase
    ALLOWED_STATUSES.include?(status) ? status : "taslak"
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
end
