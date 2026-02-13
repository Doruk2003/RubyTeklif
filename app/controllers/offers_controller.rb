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
    @offer = {}
    @items = []
  end

  def create
    payload = offer_params.to_h
    payload[:items] = Array(payload[:items])

    repository = Offers::Repository.new(client: supabase_user_client)
    offer_id = Offers::Create.new(repository: repository).call(payload: payload, user_id: current_user.id)
    redirect_to offer_path(offer_id), notice: "Teklif olusturuldu."
  rescue ServiceErrors::Base => e
    flash.now[:alert] = "Teklif olusturulamadi: #{e.user_message}"
    @offer = payload || {}
    @items = payload[:items] || []
    render :new, status: :unprocessable_entity
  end

  private

  def offer_params
    params.require(:offer).permit(
      :company_id,
      :offer_number,
      :offer_date,
      :status,
      items: %i[product_id description quantity unit_price]
    )
  end
  def authorize_offers!
    require_role!(Roles::ADMIN, Roles::SALES)
  end
end
