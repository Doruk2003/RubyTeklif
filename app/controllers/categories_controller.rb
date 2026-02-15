class CategoriesController < ApplicationController
  before_action :authorize_categories!

  def index
    result = Categories::IndexQuery.new(client: client).call(params: params)
    @categories = result[:items]
    @scope = result[:scope]
    @page = result[:page]
    @per_page = result[:per_page]
    @has_prev = result[:has_prev]
    @has_next = result[:has_next]
  rescue Supabase::Client::ConfigurationError
    @categories = []
    @scope = "active"
    @page = 1
    @per_page = 50
    @has_prev = false
    @has_next = false
  end

  def new
    @category = {}
  end

  def edit
    @category = Categories::ShowQuery.new(client: client).call(params[:id])
  rescue Supabase::Client::ConfigurationError
    @category = nil
  end

  def create
    payload = category_params
    Categories::CreateCategory.new(client: client).call(form_payload: payload, actor_id: current_user.id)
    redirect_to safe_return_to || categories_path, notice: "Kategori oluşturuldu."
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "categories#create")
    flash.now[:alert] = "Kategori oluşturulamadı: #{e.user_message}"
    @category = payload || {}
    render :new, status: :unprocessable_entity
  end

  def update
    payload = category_params
    Categories::UpdateCategory.new(client: client).call(id: params[:id], form_payload: payload, actor_id: current_user.id)
    redirect_to categories_path, notice: "Kategori güncellendi."
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "categories#update")
    flash.now[:alert] = "Kategori güncellenemedi: #{e.user_message}"
    @category = payload.merge("id" => params[:id])
    render :edit, status: :unprocessable_entity
  end

  def destroy
    Categories::ArchiveCategory.new(client: client).call(id: params[:id], actor_id: current_user.id)
    redirect_to categories_path, notice: "Kategori arşivlendi."
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "categories#destroy")
    redirect_to categories_path, alert: "Kategori arşivlenemedi: #{e.user_message}"
  end

  def restore
    Categories::RestoreCategory.new(client: client).call(id: params[:id], actor_id: current_user.id)
    redirect_to categories_path(scope: "archived"), notice: "Kategori geri yüklendi."
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "categories#restore")
    redirect_to categories_path(scope: "archived"), alert: "Kategori geri yüklenemedi: #{e.user_message}"
  end

  private

  def client
    @client ||= supabase_user_client
  end

  def category_params
    params.require(:category).permit(:code, :name, :active)
  end

  def safe_return_to
    value = params[:return_to].to_s
    return if value.blank?
    return unless value.start_with?("/")

    value
  end

  def authorize_categories!
    authorize_with_policy!(CategoriesPolicy)
  end
end
