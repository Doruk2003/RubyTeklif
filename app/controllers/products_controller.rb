class ProductsController < ApplicationController
  before_action :authorize_products!
  before_action :load_category_options, only: [:index, :show, :new, :edit, :create, :update]

  def index
    result = Products::IndexQuery.new(client: client).call(params: params)
    @products = result[:items]
    @scope = result[:scope]
    @category = params[:category].to_s.presence
    @page = result[:page]
    @per_page = result[:per_page]
    @has_prev = result[:has_prev]
    @has_next = result[:has_next]
  rescue Supabase::Client::ConfigurationError
    @products = []
    @scope = "active"
    @category = nil
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
  end

  def edit
    query = Products::FormQuery.new(client: client)
    @product = query.find_product(params[:id])
  rescue Supabase::Client::ConfigurationError
    @product = nil
  end

  def create
    payload = product_params
    product_id = Catalog::UseCases::Products::Create.new(client: client).call(form_payload: payload, actor_id: current_user.id)
    redirect_to product_path(product_id), notice: "Ürün oluşturuldu."
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "products#create")
    flash.now[:alert] = "Ürün oluşturulamadı: #{e.user_message}"
    @product = payload || {}
    render :new, status: :unprocessable_entity
  end

  def update
    payload = product_params
    result = Catalog::UseCases::Products::Update.new(client: client).call(id: params[:id], form_payload: payload, actor_id: current_user.id)
    redirect_to product_path(result[:id]), notice: "Ürün güncellendi."
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "products#update")
    flash.now[:alert] = "Ürün güncellenemedi: #{e.user_message}"
    @product = payload.merge("id" => params[:id])
    render :edit, status: :unprocessable_entity
  end

  def destroy
    Catalog::UseCases::Products::Archive.new(client: client).call(id: params[:id], actor_id: current_user.id)
    redirect_to products_path, notice: "Ürün arşivlendi."
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "products#destroy")
    redirect_to products_path, alert: "Ürün arşivlenemedi: #{e.user_message}"
  end

  def restore
    Catalog::UseCases::Products::Restore.new(client: client).call(id: params[:id], actor_id: current_user.id)
    redirect_to products_path(scope: "archived"), notice: "Urun geri yuklendi."
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "products#restore")
    redirect_to products_path(scope: "archived"), alert: "Urun geri yuklenemedi: #{e.user_message}"
  end

  private

  def client
    @client ||= supabase_user_client
  end

  def product_params
    params.require(:product).permit(:name, :price, :vat_rate, :item_type, :category_id, :active)
  end

  def authorize_products!
    authorize_with_policy!(ProductsPolicy)
  end

  def load_category_options
    rows = Categories::OptionsQuery.new(client: client).call(active_only: false, user_id: current_user.id)
    @category_options = rows.map { |row| [row["name"].to_s, row["id"].to_s] }
    @category_labels = rows.each_with_object({}) { |row, hash| hash[row["id"].to_s] = row["name"].to_s }
  rescue StandardError
    @category_options = []
    @category_labels = {}
  end
end

