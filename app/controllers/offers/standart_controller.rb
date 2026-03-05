class Offers::StandartController < ApplicationController
  before_action :authorize_offers!

  def index
    result = Offers::IndexQuery.new(client: supabase_user_client).call(params: params)
    @offers = result[:items]
    @scope = result[:scope]
    @page = result[:page]
    @per_page = result[:per_page]
    @has_prev = result[:has_prev]
    @has_next = result[:has_next]
    @companies = Companies::OptionsQuery.new(client: supabase_user_client).call(active_only: false, user_id: current_user.id)
    @company_name_map = Array(@companies).each_with_object({}) { |c, h| h[c["id"].to_s] = c["name"].to_s }
  rescue Supabase::Client::ConfigurationError
    @offers = []
    @scope = "active"
    @page = 1
    @per_page = 50
    @has_prev = false
    @has_next = false
    @company_name_map = {}
  rescue ServiceErrors::System => e
    report_handled_error(e, source: "offers/standart#index", severity: :error)
    @offers = []
    @scope = "active"
    @page = 1
    @per_page = 50
    @has_prev = false
    @has_next = false
    @company_name_map = {}
    flash.now[:alert] = e.user_message
  end

  def show
    @offer = Offers::ShowQuery.new(client: supabase_user_client).call(params[:id])
    if @offer.nil?
      flash.now[:alert] = "Teklif bulunamadi."
    end
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "offers/standart#show")
    @offer = nil
    flash.now[:alert] = e.user_message
  rescue Supabase::Client::ConfigurationError
    @offer = nil
  end

  def destroy
    Sales::UseCases::Offers::Archive.new(client: supabase_user_client).call(id: params[:id], actor_id: current_user.id)
    clear_offer_caches!
    redirect_to offers_standart_index_path, notice: "Teklif arşivlendi."
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "offers/standart#destroy")
    redirect_to offers_standart_index_path, alert: "Teklif arşivlenemedi: #{e.user_message}"
  end

  def restore
    Sales::UseCases::Offers::Restore.new(client: supabase_user_client).call(id: params[:id], actor_id: current_user.id)
    clear_offer_caches!
    redirect_to offers_standart_index_path(scope: "archived"), notice: "Teklif geri yüklendi."
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "offers/standart#restore")
    redirect_to offers_standart_index_path(scope: "archived"), alert: "Teklif geri yüklenemedi: #{e.user_message}"
  end

  def new
    if params[:offer_id].present?
      load_offer_for_continue!(params[:offer_id].to_s)
    else
      draft_id = create_draft_offer!(
        company_id: params[:company_id].to_s,
        project: params[:project].to_s,
        offer_type: "standard"
      )
      clear_offer_caches!
      redirect_to new_offers_standart_path(offer_id: draft_id) and return
    end

    @selected_category_id = params[:category_id].to_s.presence
    @items = [default_item]
    load_form_data(category_id: @selected_category_id)
  rescue Supabase::Client::ConfigurationError
    @companies = []
    @products = []
    @category_options = []
    @category_labels = {}
    @currencies = []
    @company_name ||= "Yuklenemedi"
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "offers/standart#new")
    has_flow_params = params[:offer_id].present? || params[:company_id].present? || params[:project].present?
    unless has_flow_params
      redirect_to offers_standart_index_path, alert: e.user_message and return
    end

    flash.now[:alert] = e.user_message
    @offer ||= {}
    @offer["id"] ||= ""
    @offer["company_id"] ||= params[:company_id].to_s
    @offer["offer_number"] ||= "PRJ-#{Date.current.strftime('%Y%m%d')}-001"
    @offer["offer_date"] ||= Date.current.iso8601
    @offer["status"] ||= "taslak"
    @offer["project"] ||= params[:project].to_s
    @offer["offer_type"] ||= "standard"
    @selected_category_id = params[:category_id].to_s.presence
    @items = [default_item]
    load_form_data(category_id: @selected_category_id)
    resolve_company_name
    render :new, status: :unprocessable_entity
  end
  def create
    permitted = offer_params.to_h
    @selected_category_id = permitted.delete("product_category_id").to_s.presence
    permitted["items"] = Array(permitted["items"]).map { |item| item.to_h.deep_symbolize_keys }
    payload = Offers::CreateForm.new(permitted).normalized_attributes

    if permitted["id"].present?
      offer_id = finalize_existing_offer!(offer_id: permitted["id"].to_s, payload: payload)
    else
      offer_id = Sales::UseCases::Offers::Create.new(client: supabase_user_client).call(payload: payload, user_id: current_user.id)
    end

    clear_offer_caches!
    redirect_to offers_standart_path(offer_id), notice: "Teklif olusturuldu."
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "offers/standart#create")
    flash.now[:alert] = "Teklif olusturulamadi: #{e.user_message}"
    @offer = payload.except(:items).stringify_keys
    @offer["id"] = permitted["id"].to_s if defined?(permitted) && permitted.is_a?(Hash)
    @items = payload[:items]
    load_form_data(category_id: @selected_category_id)
    resolve_company_name
    render :new, status: :unprocessable_entity
  rescue Supabase::Client::ConfigurationError
    flash.now[:alert] = "Teklif formu yuklenemedi."
    @offer = payload&.except(:items)&.stringify_keys || {}
    @items = payload&.[](:items) || [default_item]
    @companies = []
    @products = []
    @category_options = []
    @category_labels = {}
    @currencies = []
    @company_name = "Yuklenemedi"
    render :new, status: :unprocessable_entity
  end

  def calculate
    permitted = offer_params.to_h
    offer_id = permitted.delete("id").to_s
    raise ServiceErrors::Validation.new(user_message: "Teklif kimligi bulunamadi. Teklifi yeniden acip tekrar deneyin.") if offer_id.blank?
    @selected_category_id = permitted.delete("product_category_id").to_s.presence
    permitted["items"] = Array(permitted["items"]).map { |item| item.to_h.deep_symbolize_keys }
    payload = Offers::CreateForm.new(permitted).normalized_attributes

    repository = Offers::Repository.new(client: supabase_user_client)
    @product_map = repository.fetch_products(payload[:items].map { |item| item[:product_id] })
    @calculated_items = Offers::ItemBuilder.new(@product_map).build(payload[:items])
    raise ServiceErrors::Validation.new(user_message: "Lutfen en az bir poz ekleyin.") if @calculated_items.empty?

    @totals = totals_for_list_persistence(@calculated_items)
    @total_quantity = @calculated_items.sum { |item| item[:quantity].to_d }
    @grand_totals_by_currency = build_multi_currency_totals(@calculated_items)
    if offer_id.present?
      persist_payload = payload.merge(status: "beklemede")
      finalize_existing_offer!(offer_id: offer_id, payload: persist_payload)
      standart_draft_flow.apply_calculation!(offer_id: offer_id, totals: @totals, status: "beklemede")
      persist_calculation_snapshot!(offer_id: offer_id, totals: @totals)
      clear_offer_caches!
    end
    @offer = payload.except(:items).stringify_keys
    @offer["id"] = offer_id
    @offer["status"] = "beklemede"
    load_form_data(category_id: @selected_category_id)
    resolve_company_name
    @history_entries = [
      {
        message: "Proje hesaplandi.",
        at: Time.current,
        actor: current_user&.name.to_s
      }
    ]
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "offers/standart#calculate")
    flash.now[:alert] = e.user_message
    @offer = payload&.except(:items)&.stringify_keys || {}
    @offer["id"] = offer_id if defined?(offer_id)
    @items = payload&.[](:items) || [default_item]
    load_form_data(category_id: @selected_category_id)
    resolve_company_name
    render :new, status: :unprocessable_entity
  rescue Supabase::Client::ConfigurationError
    flash.now[:alert] = "Hesaplama sayfasi su anda yuklenemiyor."
    @offer = payload&.except(:items)&.stringify_keys || {}
    @offer["id"] = offer_id if defined?(offer_id)
    @items = payload&.[](:items) || [default_item]
    @companies = []
    @products = []
    @category_options = []
    @category_labels = {}
    @currencies = []
    @company_name = "Yuklenemedi"
    render :new, status: :unprocessable_entity
  end

  def sync_items
    permitted = sync_items_params.to_h
    offer_id = permitted["offer_id"].to_s
    items = Array(permitted["items"]).map { |item| item.to_h.deep_symbolize_keys }

    sync_result = standart_draft_flow.sync_draft_items!(offer_id: offer_id, items: items, update_offer_totals: false)
    clear_offer_caches!

    render json: { ok: true, items_count: sync_result[:items_count], saved_at: sync_result[:saved_at] }
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "offers/standart#sync_items")
    render json: { ok: false, error: e.user_message }, status: :unprocessable_entity
  rescue Supabase::Client::ConfigurationError
    render json: { ok: false, error: "Taslak kaydi su anda kullanilamiyor." }, status: :service_unavailable
  end

  def add_expense
    permitted = add_expense_params.to_h
    result = standart_draft_flow.add_extra_expense!(
      offer_id: permitted["offer_id"],
      description: permitted["description"],
      unit: permitted["unit"],
      quantity: permitted["quantity"],
      unit_price: permitted["unit_price"],
      vat_rate: permitted["vat_rate"]
    )
    clear_offer_caches!
    render json: { ok: true, expense: result }
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "offers/standart#add_expense")
    render json: { ok: false, error: e.user_message }, status: :unprocessable_entity
  rescue Supabase::Client::ConfigurationError
    render json: { ok: false, error: "Masraf kaydi su anda kullanilamiyor." }, status: :service_unavailable
  end

  private

  def offer_params
    params.require(:offer).permit(
      :company_id,
      :id,
      :offer_number,
      :offer_date,
      :status,
      :project,
      :offer_type,
      :product_category_id,
      items: %i[product_id description quantity unit_price discount_rate]
    )
  end

  def sync_items_params
    params.permit(:offer_id, items: %i[product_id description quantity unit_price discount_rate])
  end

  def add_expense_params
    params.permit(:offer_id, :description, :unit, :quantity, :unit_price, :vat_rate)
  end

  def load_form_data(category_id:)
    query = Offers::FormQuery.new(client: supabase_user_client)
    @companies = Companies::OptionsQuery.new(client: supabase_user_client).call(active_only: true, user_id: current_user.id)
    @products = query.products(category_id: category_id, user_id: current_user.id)
    category_rows = Categories::OptionsQuery.new(client: supabase_user_client).call(active_only: true, user_id: current_user.id)
    @category_options = category_rows.map { |row| [row["name"].to_s, row["id"].to_s] }
    @category_labels = category_rows.each_with_object({}) { |row, hash| hash[row["id"].to_s] = row["name"].to_s }
    @currencies = Currencies::OptionsQuery.new(client: supabase_user_client).call(active_only: true, user_id: current_user.id)
  rescue ServiceErrors::System => e
    report_handled_error(e, source: "offers/standart#load_form_data", severity: :error)
    flash.now[:alert] ||= e.user_message
    @companies = []
    @products = []
    @category_options = []
    @category_labels = {}
    @currencies = []
  rescue StandardError
    @companies = []
    @products = []
    @category_options = []
    @category_labels = {}
    @currencies = []
  end

  def resolve_company_name
    cid = @offer&.dig("company_id").to_s
    if cid.present? && Array(@companies).any?
      found = @companies.find { |c| c["id"].to_s == cid }
      @company_name = found ? found["name"] : "Bilinmeyen Müşteri"
    else
      @company_name ||= "Müşteri Seçilmedi"
    end
  end

  def create_draft_offer!(company_id:, project:, offer_type:)
    standart_draft_flow.create_draft_offer!(company_id: company_id, project: project, offer_type: offer_type)
  end

  def load_offer_for_continue!(offer_id)
    result = standart_draft_flow.load_offer_for_continue!(offer_id: offer_id)
    @offer = result[:offer]
    @company_name = result[:company_name]
  end

  def finalize_existing_offer!(offer_id:, payload:)
    standart_draft_flow.finalize_existing_offer!(offer_id: offer_id, payload: payload)
  end

  def standart_draft_flow
    @standart_draft_flow ||= Offers::StandartDraftFlow.new(client: supabase_user_client, user_id: current_user.id)
  end

  def default_item
    { product_id: "", description: "", quantity: "1", unit_price: "", discount_rate: "0" }
  end

  def authorize_offers!
    authorize_with_policy!(OffersPolicy)
  end

  def clear_offer_caches!
    QueryCacheInvalidator.new.invalidate_offers!(user_id: current_user.id)
  end

  def persist_calculation_snapshot!(offer_id:, totals:)
    now_iso = Time.now.utc.iso8601
    supabase_user_client.patch(
      "offers?id=eq.#{Supabase::FilterValue.eq(offer_id)}&user_id=eq.#{Supabase::FilterValue.eq(current_user.id)}&deleted_at=is.null",
      body: {
        status: "beklemede",
        net_total: totals[:net_total].to_s,
        vat_total: totals[:vat_total].to_s,
        gross_total: totals[:gross_total].to_s,
        updated_at: now_iso
      },
      headers: { "Prefer" => "return=minimal" }
    )
  end

  def build_multi_currency_totals(items)
    rows = Array(items)
    return [] if rows.empty?

    rate_map = {}
    symbol_map = {}
    rows.each do |item|
      code = item[:currency_code].to_s.upcase.presence || "TRY"
      symbol = item[:currency_symbol].to_s.presence
      rate = normalize_currency_rate(item[:currency_rate_to_try], code)
      rate_map[code] ||= rate
      symbol_map[code] ||= symbol
    end

    gross_try_total = rows.sum do |item|
      code = item[:currency_code].to_s.upcase.presence || "TRY"
      rate = rate_map[code] || BigDecimal("1")
      line_total = item[:line_total].to_d
      vat_amount = line_total * item[:vat_rate].to_d / 100
      (line_total + vat_amount) * rate
    end

    rate_map.keys.map do |code|
      rate = rate_map[code]
      amount = rate.positive? ? (gross_try_total / rate) : BigDecimal("0")
      {
        code: code,
        symbol: symbol_map[code].to_s.presence || code,
        amount: amount
      }
    end
  end

  def totals_for_list_persistence(items)
    rows = Array(items)
    return Offers::TotalsCalculator.new.call(rows) if rows.empty?

    currency_codes = rows.map { |item| item[:currency_code].to_s.upcase.presence || "TRY" }.uniq
    return Offers::TotalsCalculator.new.call(rows) if currency_codes.size <= 1

    net_try_total = BigDecimal("0")
    vat_try_total = BigDecimal("0")

    rows.each do |item|
      code = item[:currency_code].to_s.upcase.presence || "TRY"
      rate = normalize_currency_rate(item[:currency_rate_to_try], code)
      line_total = item[:line_total].to_d
      vat_amount = line_total * item[:vat_rate].to_d / 100
      net_try_total += (line_total * rate)
      vat_try_total += (vat_amount * rate)
    end

    {
      net_total: net_try_total,
      vat_total: vat_try_total,
      gross_total: net_try_total + vat_try_total
    }
  end

  def normalize_currency_rate(raw_rate, code)
    return BigDecimal("1") if code.to_s.upcase == "TRY"

    rate = raw_rate.to_d
    rate.positive? ? rate : BigDecimal("1")
  end
end
