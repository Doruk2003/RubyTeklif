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
  rescue Supabase::Client::ConfigurationError
    @offers = []
    @scope = "active"
    @page = 1
    @per_page = 50
    @has_prev = false
    @has_next = false
  rescue ServiceErrors::System => e
    report_handled_error(e, source: "offers/standart#index", severity: :error)
    @offers = []
    @scope = "active"
    @page = 1
    @per_page = 50
    @has_prev = false
    @has_next = false
    flash.now[:alert] = e.user_message
  end

  def show
    @offer = Offers::ShowQuery.new(client: supabase_user_client).call(params[:id])
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
    @offer = {
      "company_id" => params[:company_id].to_s,
      "project" => params[:project].to_s,
      "offer_date" => Date.current.iso8601,
      "status" => "taslak"
    }

    # Auto-generate project number
    @offer["offer_number"] = "PRJ-#{Date.current.strftime('%Y%m%d')}-#{SecureRandom.hex(2).upcase}"

    # Fetch selected company name for display
    if @offer["company_id"].present?
      company_data = Companies::OptionsQuery.new(client: supabase_user_client).call(
        active_only: false, user_id: current_user.id, q: nil
      )
      found = company_data.find { |c| c["id"].to_s == @offer["company_id"] }
      @company_name = found ? found["name"] : "Bilinmeyen Müşteri"
    else
      @company_name = "Müşteri Seçilmedi"
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
    @company_name ||= "Yüklenemedi"
  end

  def create
    permitted = offer_params.to_h
    @selected_category_id = permitted.delete("product_category_id").to_s.presence
    permitted["items"] = Array(permitted["items"]).map { |item| item.to_h.deep_symbolize_keys }
    payload = Offers::CreateForm.new(permitted).normalized_attributes

    offer_id = Sales::UseCases::Offers::Create.new(client: supabase_user_client).call(payload: payload, user_id: current_user.id)
    clear_offer_caches!
    redirect_to offers_standart_path(offer_id), notice: "Teklif oluşturuldu."
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "offers/standart#create")
    flash.now[:alert] = "Teklif oluşturulamadı: #{e.user_message}"
    @offer = payload.except(:items).stringify_keys
    @items = payload[:items]
    load_form_data(category_id: @selected_category_id)
    resolve_company_name
    render :new, status: :unprocessable_entity
  rescue Supabase::Client::ConfigurationError
    flash.now[:alert] = "Teklif formu yüklenemedi."
    @offer = payload&.except(:items)&.stringify_keys || {}
    @items = payload&.[](:items) || [default_item]
    @companies = []
    @products = []
    @category_options = []
    @category_labels = {}
    @currencies = []
    @company_name = "Yüklenemedi"
    render :new, status: :unprocessable_entity
  end

  private

  def offer_params
    params.require(:offer).permit(
      :company_id,
      :offer_number,
      :offer_date,
      :status,
      :project,
      :offer_type,
      :product_category_id,
      items: %i[product_id description quantity unit_price discount_rate]
    )
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

  def default_item
    { product_id: "", description: "", quantity: "1", unit_price: "", discount_rate: "0" }
  end

  def authorize_offers!
    authorize_with_policy!(OffersPolicy)
  end

  def clear_offer_caches!
    QueryCacheInvalidator.new.invalidate_offers!(user_id: current_user.id)
  end
end
