class ProductsController < ApplicationController
  before_action :authorize_products!
  before_action :load_category_options, only: [:index, :show, :new, :edit, :create, :update]
  before_action :load_brand_options, only: [:index, :show, :new, :edit, :create, :update]
  before_action :load_currency_options, only: [:index, :show, :new, :edit, :create, :update]
  before_action :load_product_images, only: [:show, :edit, :update]

  def index
    result = Products::IndexQuery.new(client: client).call(params: params, user_id: current_user.id)
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
  rescue ServiceErrors::System => e
    report_handled_error(e, source: "products#index", severity: :error)
    @products = []
    @scope = "active"
    @category = nil
    @page = 1
    @per_page = 50
    @has_prev = false
    @has_next = false
    flash.now[:alert] = e.user_message
  end

  def show
    @product = Products::ShowQuery.new(client: client).call(params[:id])
  rescue Supabase::Client::ConfigurationError
    @product = nil
  end

  def new
    @product = {}
    @product_images = []
  end

  def edit
    @product = Products::ShowQuery.new(client: client).call(params[:id])
  rescue Supabase::Client::ConfigurationError
    @product = nil
  end

  def create
    payload = product_payload
    photos = product_photos
    validate_photo_limit!(incoming_count: photos.size, existing_count: 0)

    product_id = Catalog::UseCases::Products::Create.new(client: client).call(form_payload: payload, actor_id: current_user.id)
    attach_product_photos!(product_id: product_id, photos: photos)
    clear_products_cache!
    redirect_to product_path(product_id), notice: "Urun olusturuldu."
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "products#create")
    flash.now[:alert] = "Urun olusturulamadi: #{e.user_message}"
    @product = payload || {}
    @product_images = []
    render :new, status: :unprocessable_entity
  end

  def update
    payload = product_payload
    photos = product_photos
    validate_photo_limit!(incoming_count: photos.size, existing_count: @product_images.to_a.size)

    result = Catalog::UseCases::Products::Update.new(client: client).call(id: params[:id], form_payload: payload, actor_id: current_user.id)
    attach_product_photos!(product_id: result[:id], photos: photos)
    clear_products_cache!
    redirect_to product_path(result[:id]), notice: "Urun guncellendi."
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "products#update")
    flash.now[:alert] = "Urun guncellenemedi: #{e.user_message}"
    @product = payload.merge("id" => params[:id])
    render :edit, status: :unprocessable_entity
  end

  def destroy
    Catalog::UseCases::Products::Archive.new(client: client).call(id: params[:id], actor_id: current_user.id)
    purge_warning = purge_archived_product_images_warning(product_id: params[:id])
    clear_products_cache!
    redirect_to products_path, notice: "Urun arsivlendi.", alert: purge_warning
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "products#destroy")
    redirect_to products_path, alert: "Urun arsivlenemedi: #{e.user_message}"
  end

  def restore
    Catalog::UseCases::Products::Restore.new(client: client).call(id: params[:id], actor_id: current_user.id)
    clear_products_cache!
    redirect_to products_path(scope: "archived"), notice: "Urun geri yuklendi."
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "products#restore")
    redirect_to products_path(scope: "archived"), alert: "Urun geri yuklenemedi: #{e.user_message}"
  end

  def destroy_image
    ProductImages::Remove.new(client: client, access_token: session[:access_token].to_s).call(
      product_id: params[:id],
      image_id: params[:image_id],
      user_id: current_user.id
    )
    redirect_to edit_product_path(params[:id]), notice: "Fotograf silindi."
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "products#destroy_image")
    redirect_to edit_product_path(params[:id]), alert: "Fotograf silinemedi: #{e.user_message}"
  end

  def move_image
    ProductImages::Reorder.new(client: client).move(
      product_id: params[:id],
      image_id: params[:image_id],
      user_id: current_user.id,
      direction: params[:direction]
    )
    redirect_to edit_product_path(params[:id]), notice: "Fotograf sirasi guncellendi."
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "products#move_image")
    redirect_to edit_product_path(params[:id]), alert: "Fotograf sirasi guncellenemedi: #{e.user_message}"
  end

  private

  def client
    @client ||= supabase_user_client
  end

  def product_params
    params.require(:product).permit(
      :sku,
      :name,
      :description,
      :barcode,
      :price,
      :vat_rate,
      :item_type,
      :category_id,
      :brand_id,
      :currency_id,
      :unit,
      :is_stock_item,
      :cost_price,
      :stock_quantity,
      :min_stock_level,
      :sale_price_vat_included,
      :cost_price_vat_included,
      :active,
      photos: []
    )
  end

  def product_payload
    product_params.except(:photos)
  end

  def product_photos
    Array(product_params[:photos]).select { |file| file.respond_to?(:content_type) }.reject { |file| file.respond_to?(:original_filename) && file.original_filename.to_s.blank? }
  end

  def authorize_products!
    authorize_with_policy!(ProductsPolicy)
  end

  def load_category_options
    rows = Categories::OptionsQuery.new(client: client).call(active_only: false, user_id: current_user.id)
    @category_options = rows.map { |row| [row["name"].to_s, row["id"].to_s] }
    @category_labels = rows.each_with_object({}) { |row, hash| hash[row["id"].to_s] = row["name"].to_s }
  rescue ServiceErrors::System => e
    report_handled_error(e, source: "products#load_category_options", severity: :error)
    flash.now[:alert] ||= e.user_message
    @category_options = []
    @category_labels = {}
  rescue StandardError
    @category_options = []
    @category_labels = {}
  end

  def load_brand_options
    rows = Brands::OptionsQuery.new(client: client).call(active_only: false, user_id: current_user.id)
    @brand_options = rows.map { |row| [row["name"].to_s, row["id"].to_s] }
    @brand_labels = rows.each_with_object({}) { |row, hash| hash[row["id"].to_s] = row["name"].to_s }
  rescue ServiceErrors::System => e
    report_handled_error(e, source: "products#load_brand_options", severity: :error)
    flash.now[:alert] ||= e.user_message
    @brand_options = []
    @brand_labels = {}
  rescue StandardError
    @brand_options = []
    @brand_labels = {}
  end

  def load_currency_options
    rows = Currencies::OptionsQuery.new(client: client).call(active_only: false, user_id: current_user.id)
    @currency_options = rows.map { |row| [row["name"].to_s, row["id"].to_s] }
    @currency_labels = rows.each_with_object({}) { |row, hash| hash[row["id"].to_s] = row["name"].to_s }
  rescue ServiceErrors::System => e
    report_handled_error(e, source: "products#load_currency_options", severity: :error)
    flash.now[:alert] ||= e.user_message
    @currency_options = []
    @currency_labels = {}
  rescue StandardError
    @currency_options = []
    @currency_labels = {}
  end

  def load_product_images
    @product_images = ProductImages::Repository.new(client: client).list(product_id: params[:id], user_id: current_user.id)
  rescue StandardError
    @product_images = []
  end

  def attach_product_photos!(product_id:, photos:)
    return if photos.blank?

    ProductImages::Attach.new(client: client, access_token: session[:access_token].to_s).call(
      product_id: product_id,
      user_id: current_user.id,
      files: photos
    )
  end

  def validate_photo_limit!(incoming_count:, existing_count:)
    max_count = ProductImages::Attach::MAX_PHOTO_COUNT
    return if (incoming_count + existing_count) <= max_count

    raise ServiceErrors::Validation.new(
      user_message: "En fazla #{max_count} urun fotografi yukleyebilirsiniz. Mevcut: #{existing_count}, yeni: #{incoming_count}."
    )
  end

  def clear_products_cache!
    QueryCacheInvalidator.new.invalidate_products!(user_id: current_user.id)
  end

  def purge_archived_product_images_warning(product_id:)
    ProductImages::PurgeForProduct.new(client: client, access_token: session[:access_token].to_s).call(
      product_id: product_id,
      user_id: current_user.id
    )
    nil
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "products#purge_images_after_archive")
    "Urun arsivlendi ancak fotograflar temizlenemedi: #{e.user_message}"
  rescue StandardError => e
    report_handled_error(e, source: "products#purge_images_after_archive")
    "Urun arsivlendi ancak fotograflar temizlenemedi."
  end
end
