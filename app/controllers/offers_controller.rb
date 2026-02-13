class OffersController < ApplicationController
  before_action :authorize_offers!

  def index
    result = Offers::IndexQuery.new(client: supabase_user_client).call(params: params)
    @offers = result[:items]
    @page = result[:page]
    @per_page = result[:per_page]
    @has_prev = result[:has_prev]
    @has_next = result[:has_next]
  rescue Supabase::Client::ConfigurationError
    @offers = []
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

  def new
    @offer = {
      "company_id" => params[:company_id].to_s,
      "offer_date" => Date.current.iso8601,
      "status" => "taslak"
    }
    @selected_category = params[:category].to_s.presence
    @items = [default_item]
    load_form_data(company_id: @offer["company_id"], category: @selected_category)
  rescue Supabase::Client::ConfigurationError
    @companies = []
    @products = []
  end

  def create
    payload = offer_params.to_h.deep_symbolize_keys
    @selected_category = payload.delete(:product_category).to_s.presence
    payload[:items] = Array(payload[:items]).map { |item| item.to_h.deep_symbolize_keys }

    repository = Offers::Repository.new(client: supabase_user_client)
    offer_id = Offers::Create.new(repository: repository).call(payload: payload, user_id: current_user.id)
    redirect_to offer_path(offer_id), notice: "Teklif olusturuldu."
  rescue ServiceErrors::Base => e
    flash.now[:alert] = "Teklif olusturulamadi: #{e.user_message}"
    @offer = payload.except(:items).stringify_keys
    @items = payload[:items]
    load_form_data(company_id: @offer["company_id"], category: @selected_category)
    render :new, status: :unprocessable_entity
  rescue Supabase::Client::ConfigurationError
    flash.now[:alert] = "Teklif formu yuklenemedi."
    @offer = payload&.except(:items)&.stringify_keys || {}
    @items = payload&.[](:items) || [default_item]
    @companies = []
    @products = []
    render :new, status: :unprocessable_entity
  end

  private

  def offer_params
    params.require(:offer).permit(
      :company_id,
      :offer_number,
      :offer_date,
      :status,
      :product_category,
      items: %i[product_id description quantity unit_price discount_rate]
    )
  end

  def load_form_data(company_id:, category:)
    query = Offers::FormQuery.new(client: supabase_user_client)
    @companies = query.companies
    @products = query.products(company_id: company_id, category: category)
  end

  def default_item
    { product_id: "", description: "", quantity: "1", unit_price: "", discount_rate: "0" }
  end

  def authorize_offers!
    require_role!(Roles::ADMIN, Roles::SALES)
  end
end
