class CategoriesController < ApplicationController
  before_action :authorize_categories!

  def index
    result = Categories::IndexQuery.new(client: client).call(params: params)
    @categories = result[:items]
    @scope = result[:scope]
    @active = result[:active]
    @q = result[:q]
    @sort = result[:sort]
    @dir = result[:dir]
    @page = result[:page]
    @per_page = result[:per_page]
    @has_prev = result[:has_prev]
    @has_next = result[:has_next]
  rescue Supabase::Client::ConfigurationError
    @categories = []
    @scope = "active"
    @active = ""
    @q = ""
    @sort = "name"
    @dir = "asc"
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
    Catalog::UseCases::Categories::Create.new(client: client).call(form_payload: payload, actor_id: current_user.id)
    redirect_to safe_return_to || categories_path, notice: "Kategori oluÅŸturuldu."
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "categories#create")
    flash.now[:alert] = "Kategori oluÅŸturulamadÄ±: #{e.user_message}"
    @category = payload || {}
    render :new, status: :unprocessable_entity
  end

  def update
    payload = category_params
    Catalog::UseCases::Categories::Update.new(client: client).call(id: params[:id], form_payload: payload, actor_id: current_user.id)
    redirect_to categories_path, notice: "Kategori gÃ¼ncellendi."
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "categories#update")
    flash.now[:alert] = "Kategori gÃ¼ncellenemedi: #{e.user_message}"
    @category = payload.merge("id" => params[:id])
    render :edit, status: :unprocessable_entity
  end

  def destroy
    Catalog::UseCases::Categories::Archive.new(client: client).call(id: params[:id], actor_id: current_user.id)
    redirect_to categories_path, notice: "Kategori arÅŸivlendi."
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "categories#destroy")
    redirect_to categories_path, alert: "Kategori arÅŸivlenemedi: #{e.user_message}"
  end

  def restore
    Catalog::UseCases::Categories::Restore.new(client: client).call(id: params[:id], actor_id: current_user.id)
    redirect_to categories_path(scope: "archived"), notice: "Kategori geri yÃ¼klendi."
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "categories#restore")
    redirect_to categories_path(scope: "archived"), alert: "Kategori geri yÃ¼klenemedi: #{e.user_message}"
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

