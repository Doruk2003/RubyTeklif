class OffersController < ApplicationController
  before_action :authorize_offers!

  def index
    @offers = Offers::IndexQuery.new.call
  rescue Supabase::Client::ConfigurationError
    @offers = []
  end

  def show
    @offer = Offers::ShowQuery.new.call(params[:id])
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

    offer_id = Offers::Create.new.call(payload: payload, user_id: service_user_id)
    redirect_to offer_path(offer_id), notice: "Teklif olusturuldu."
  rescue StandardError => e
    flash.now[:alert] = "Teklif olusturulamadi: #{e.message}"
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

  def service_user_id
    ENV.fetch("SUPABASE_SERVICE_USER_ID")
  end

  def authorize_offers!
    require_role!(Roles::ADMIN, Roles::SALES)
  end
end
