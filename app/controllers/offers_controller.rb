class OffersController < ApplicationController
  before_action :authorize_offers!

  def index
    result = Offers::IndexQuery.new(client: supabase_user_client).call(params: params)
    @offers = result[:items]
    @scope = result[:scope]
    @page = result[:page]
    @per_page = result[:per_page]
    @has_prev = result[:has_prev]
    @has_next = result[:has_next]
  rescue Supabase::Client::ConfigurationError
    @offers = []
    @scope = "active"
    @page = 1
    @per_page = 50
    @has_prev = false
    @has_next = false
  end

  def show
    @offer = Offers::ShowQuery.new(client: supabase_user_client).call(params[:id])
  rescue Supabase::Client::ConfigurationError
    @offer = nil
  end

  def destroy
    Sales::UseCases::Offers::Archive.new(client: supabase_user_client).call(id: params[:id], actor_id: current_user.id)
    redirect_to offers_path, notice: "Teklif arşivlendi."
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "offers#destroy")
    redirect_to offers_path, alert: "Teklif arşivlenemedi: #{e.user_message}"
  end

  def restore
    Sales::UseCases::Offers::Restore.new(client: supabase_user_client).call(id: params[:id], actor_id: current_user.id)
    redirect_to offers_path(scope: "archived"), notice: "Teklif geri yüklendi."
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "offers#restore")
    redirect_to offers_path(scope: "archived"), alert: "Teklif geri yüklenemedi: #{e.user_message}"
  end

  def new
    @offer = {
      "company_id" => params[:company_id].to_s,
      "offer_date" => Date.current.iso8601,
      "status" => "taslak"
    }
    @selected_category_id = params[:category_id].to_s.presence
    @items = [default_item]
    load_form_data(category_id: @selected_category_id)
  rescue Supabase::Client::ConfigurationError
    @companies = []
    @products = []
    @category_options = []
    @category_labels = {}
  end

  def create
    permitted = offer_params.to_h
    @selected_category_id = permitted.delete("product_category_id").to_s.presence
    permitted["items"] = Array(permitted["items"]).map { |item| item.to_h.deep_symbolize_keys }
    payload = Offers::CreateForm.new(permitted).normalized_attributes

    offer_id = Sales::UseCases::Offers::Create.new(client: supabase_user_client).call(payload: payload, user_id: current_user.id)
    redirect_to offer_path(offer_id), notice: "Teklif oluşturuldu."
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "offers#create")
    flash.now[:alert] = "Teklif oluşturulamadı: #{e.user_message}"
    @offer = payload.except(:items).stringify_keys
    @items = payload[:items]
    load_form_data(category_id: @selected_category_id)
    render :new, status: :unprocessable_entity
  rescue Supabase::Client::ConfigurationError
    flash.now[:alert] = "Teklif formu yüklenemedi."
    @offer = payload&.except(:items)&.stringify_keys || {}
    @items = payload&.[](:items) || [default_item]
    @companies = []
    @products = []
    @category_options = []
    @category_labels = {}
    render :new, status: :unprocessable_entity
  end

  private

  def offer_params
    params.require(:offer).permit(
      :company_id,
      :offer_number,
      :offer_date,
      :status,
      :product_category_id,
      items: %i[product_id description quantity unit_price discount_rate]
    )
  end

  def load_form_data(category_id:)
    query = Offers::FormQuery.new(client: supabase_user_client)
    @companies = query.companies(user_id: current_user.id)
    @products = query.products(category_id: category_id, user_id: current_user.id)
    category_rows = Categories::OptionsQuery.new(client: supabase_user_client).call(active_only: true, user_id: current_user.id)
    @category_options = category_rows.map { |row| [row["name"].to_s, row["id"].to_s] }
    @category_labels = category_rows.each_with_object({}) { |row, hash| hash[row["id"].to_s] = row["name"].to_s }
  rescue StandardError
    @companies = []
    @products = []
    @category_options = []
    @category_labels = {}
  end

  def default_item
    { product_id: "", description: "", quantity: "1", unit_price: "", discount_rate: "0" }
  end

  def authorize_offers!
    authorize_with_policy!(OffersPolicy)
  end
end

