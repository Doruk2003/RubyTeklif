class CurrenciesController < ApplicationController
  before_action :authorize_currencies!

  def index
    result = Currencies::IndexQuery.new(client: client).call(params: params)
    @currencies = result[:items]
    @page = result[:page]
    @per_page = result[:per_page]
    @has_prev = result[:has_prev]
    @has_next = result[:has_next]
  rescue Supabase::Client::ConfigurationError
    @currencies = []
    @page = 1
    @per_page = 50
    @has_prev = false
    @has_next = false
  end

  def new
    @currency = {}
  end

  def create
    payload = currency_params
    Currencies::Create.new(client: client).call(form_payload: payload, actor_id: current_user.id)
    redirect_to currencies_path, notice: "Kur kaydi olusturuldu."
  rescue ServiceErrors::Base => e
    flash.now[:alert] = "Kur kaydi olusturulamadi: #{e.user_message}"
    @currency = payload || {}
    render :new, status: :unprocessable_entity
  end

  def edit
    @currency = Currencies::ShowQuery.new(client: client).call(params[:id])
  rescue Supabase::Client::ConfigurationError
    @currency = nil
  end

  def update
    payload = currency_params
    Currencies::Update.new(client: client).call(id: params[:id], form_payload: payload, actor_id: current_user.id)
    redirect_to currencies_path, notice: "Kur guncellendi."
  rescue ServiceErrors::Base => e
    flash.now[:alert] = "Kur guncellenemedi: #{e.user_message}"
    @currency = payload.merge("id" => params[:id])
    render :edit, status: :unprocessable_entity
  end

  def destroy
    Currencies::Destroy.new(client: client).call(id: params[:id], actor_id: current_user.id)
    redirect_to currencies_path, notice: "Kur silindi."
  rescue ServiceErrors::Base => e
    redirect_to currencies_path, alert: "Kur silinemedi: #{e.user_message}"
  end

  private

  def client
    @client ||= supabase_user_client
  end

  def currency_params
    params.require(:currency).permit(:code, :name, :symbol, :rate_to_try, :active)
  end

  def authorize_currencies!
    require_role!(Roles::ADMIN, Roles::FINANCE)
  end
end
