class BrandsController < ApplicationController
  before_action :authorize_brands!

  def new
    @brand = {}
  end

  def create
    payload = brand_params
    Catalog::UseCases::Brands::Create.new(client: client).call(form_payload: payload, actor_id: current_user.id)
    clear_brands_cache!
    redirect_to safe_return_to || products_path, notice: "Marka oluşturuldu."
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "brands#create")
    flash.now[:alert] = "Marka oluşturulamadı: #{e.user_message}"
    @brand = payload || {}
    render :new, status: :unprocessable_entity
  end

  private

  def client
    @client ||= supabase_user_client
  end

  def brand_params
    params.require(:brand).permit(:code, :name, :active)
  end

  def safe_return_to
    value = params[:return_to].to_s
    return if value.blank?
    return unless value.start_with?("/")

    value
  end

  def authorize_brands!
    authorize_with_policy!(BrandsPolicy)
  end

  def clear_brands_cache!
    Rails.cache.delete_matched("brands/options/v1/user:#{current_user.id}/*")
  end
end
