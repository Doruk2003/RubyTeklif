class ProductsController < ApplicationController
  before_action :authorize_products!

  def index
    result = Products::IndexQuery.new(client: client).call(params: params)
    @products = result[:items]
    @page = result[:page]
    @per_page = result[:per_page]
    @has_prev = result[:has_prev]
    @has_next = result[:has_next]
  rescue Supabase::Client::ConfigurationError
    @products = []
    @page = 1
    @per_page = 50
    @has_prev = false
    @has_next = false
  end

  def show
    @product = Products::ShowQuery.new(client: client).call(params[:id])
  rescue Supabase::Client::ConfigurationError
    @product = nil
  end

  def new
    @product = {}
    @companies = Products::FormQuery.new(client: client).companies
  end

  def edit
    query = Products::FormQuery.new(client: client)
    @product = query.find_product(params[:id])
    @companies = query.companies
  rescue Supabase::Client::ConfigurationError
    @product = nil
    @companies = []
  end

  def create
    payload = product_params
    product_id = Products::Create.new(client: client).call(form_payload: payload, actor_id: current_user.id)
    redirect_to product_path(product_id), notice: "Urun olusturuldu."
  rescue ServiceErrors::Base => e
    flash.now[:alert] = "Urun olusturulamadi: #{e.user_message}"
    @product = payload || {}
    @companies = Products::FormQuery.new(client: client).companies
    render :new, status: :unprocessable_entity
  end

  def update
    payload = product_params
    result = Products::Update.new(client: client).call(id: params[:id], form_payload: payload, actor_id: current_user.id)
    redirect_to product_path(result[:id]), notice: "Urun guncellendi."
  rescue ServiceErrors::Base => e
    flash.now[:alert] = "Urun guncellenemedi: #{e.user_message}"
    @product = payload.merge("id" => params[:id])
    @companies = Products::FormQuery.new(client: client).companies
    render :edit, status: :unprocessable_entity
  end

  def destroy
    Products::Destroy.new(client: client).call(id: params[:id], actor_id: current_user.id)
    redirect_to products_path, notice: "Urun silindi."
  rescue ServiceErrors::Base => e
    redirect_to products_path, alert: "Urun silinemedi: #{e.user_message}"
  end

  private

  def client
    @client ||= supabase_user_client
  end

  def product_params
    params.require(:product).permit(:company_id, :name, :price, :vat_rate, :item_type, :active)
  end

  def authorize_products!
    require_role!(Roles::ADMIN, Roles::SALES)
  end
end
