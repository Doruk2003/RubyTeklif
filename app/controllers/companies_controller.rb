class CompaniesController < ApplicationController
  before_action :authorize_companies!

  def options
    companies = Companies::OptionsQuery.new(client: client).call(
      active_only: false,
      user_id: current_user.id,
      q: params[:q]
    )
    render json: companies.map { |c| { id: c["id"], name: c["name"] } }
  end

  def index
    result = Companies::IndexQuery.new(client: client).call(params: params, user_id: current_user.id)
    @companies = result[:items]
    @scope = result[:scope]
    @page = result[:page]
    @per_page = result[:per_page]
    @has_prev = result[:has_prev]
    @has_next = result[:has_next]
  rescue Supabase::Client::ConfigurationError
    @companies = []
    @scope = "active"
    @page = 1
    @per_page = 50
    @has_prev = false
    @has_next = false
    flash.now[:alert] = "Supabase ayarlari eksik oldugu icin musteriler yuklenemedi."
  rescue ServiceErrors::System => e
    report_handled_error(e, source: "companies#index", severity: :error)
    @companies = []
    @scope = "active"
    @page = 1
    @per_page = 50
    @has_prev = false
    @has_next = false
    flash.now[:alert] = e.user_message
  end

  def show
    @company = Companies::ShowQuery.new(client: client).call(params[:id])
    if @company.nil?
      redirect_to companies_path, alert: "Musteri bulunamadi."
      return
    end

    @offers = []
  end

  def new
    @company = Company.new(active: true)
  end

  def create
    form_payload = company_params
    result = Catalog::UseCases::Companies::Create.new(client: client).call(form_payload: form_payload, actor_id: current_user.id)
    clear_companies_cache!
    redirect_to companies_path, notice: result[:notice]
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "companies#create")
    flash.now[:alert] = "Musteri olusturulamadi: #{e.user_message}"
    @company = Company.new(form_payload || {})
    render :new, status: :unprocessable_entity
  end

  def edit
    @company = Companies::ShowQuery.new(client: client).call(params[:id])
    if @company.nil?
      redirect_to companies_path, alert: "Musteri bulunamadi."
      return
    end
  end

  def update
    payload = company_params
    Catalog::UseCases::Companies::Update.new(client: client).call(id: params[:id], form_payload: payload, actor_id: current_user.id)
    clear_companies_cache!
    company_name = payload[:name].to_s.strip
    notice_text = company_name.present? ? "#{company_name} güncellendi." : "Müşteri güncellendi."
    redirect_to company_path(params[:id]), notice: notice_text
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "companies#update")
    flash.now[:alert] = "Musteri guncellenemedi: #{e.user_message}"
    @company = Company.new(payload.merge(id: params[:id]))
    render :edit, status: :unprocessable_entity
  end

  def destroy
    Catalog::UseCases::Companies::Archive.new(client: client).call(id: params[:id], actor_id: current_user.id)
    clear_companies_cache!
    redirect_to companies_path, notice: "Müşteri arşivlendi."
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "companies#destroy")
    redirect_to companies_path, alert: "Müşteri arşivlenemedi: #{e.user_message}"
  end

  def restore
    Catalog::UseCases::Companies::Restore.new(client: client).call(id: params[:id], actor_id: current_user.id)
    clear_companies_cache!
    redirect_to companies_path(scope: "active"), notice: "Müşteri geri yüklendi."
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "companies#restore")
    redirect_to companies_path(scope: "archived"), alert: "Müşteri geri yüklenemedi: #{e.user_message}"
  end

  private

  def company_params
    params.require(:company).permit(:name, :tax_number, :tax_office, :authorized_person, :phone, :email, :address, :description, :city, :country, :active)
  end

  def client
    @client ||= supabase_user_client
  end

  def authorize_companies!
    authorize_with_policy!(CompaniesPolicy)
  end

  def clear_companies_cache!
    QueryCacheInvalidator.new.invalidate_companies!(user_id: current_user.id)
  end
end
