class CategoriesController < ApplicationController
  before_action :authorize_categories!

  def index
    result = Categories::IndexQuery.new(client: client).call(params: params)
    @categories = result[:items]
    @page = result[:page]
    @per_page = result[:per_page]
    @has_prev = result[:has_prev]
    @has_next = result[:has_next]
  rescue Supabase::Client::ConfigurationError
    @categories = []
    @page = 1
    @per_page = 50
    @has_prev = false
    @has_next = false
  end

  def new
    @category = {}
  end

  def create
    payload = category_params
    Categories::Create.new(client: client).call(form_payload: payload, actor_id: current_user.id)
    redirect_to safe_return_to || categories_path, notice: "Kategori oluÅŸturuldu."
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "categories#create")
    flash.now[:alert] = "Kategori oluÅŸturulamadÄ±: #{e.user_message}"
    @category = payload || {}
    render :new, status: :unprocessable_entity
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
