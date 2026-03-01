class Offers::StandartController < ApplicationController
  before_action :authorize_offers!

  def index
    result = Offers::IndexQuery.new(client: supabase_user_client).call(params: params)
    @offers = result[:items]
    @scope = result[:scope]
    @page = result[:page]
    @per_page = result[:per_page]
    @has_prev = result[:has_prev]
    @has_next = result[:has_next]
    @companies = Companies::OptionsQuery.new(client: supabase_user_client).call(active_only: false, user_id: current_user.id)
  rescue Supabase::Client::ConfigurationError
    @offers = []
    @scope = "active"
    @page = 1
    @per_page = 50
    @has_prev = false
    @has_next = false
  rescue ServiceErrors::System => e
    report_handled_error(e, source: "offers/standart#index", severity: :error)
    @offers = []
    @scope = "active"
    @page = 1
    @per_page = 50
    @has_prev = false
    @has_next = false
    flash.now[:alert] = e.user_message
  end

  def show
    @offer = Offers::ShowQuery.new(client: supabase_user_client).call(params[:id])
  rescue Supabase::Client::ConfigurationError
    @offer = nil
  end

  def destroy
    Sales::UseCases::Offers::Archive.new(client: supabase_user_client).call(id: params[:id], actor_id: current_user.id)
    clear_offer_caches!
    redirect_to offers_standart_index_path, notice: "Teklif arşivlendi."
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "offers/standart#destroy")
    redirect_to offers_standart_index_path, alert: "Teklif arşivlenemedi: #{e.user_message}"
  end

  def restore
    Sales::UseCases::Offers::Restore.new(client: supabase_user_client).call(id: params[:id], actor_id: current_user.id)
    clear_offer_caches!
    redirect_to offers_standart_index_path(scope: "archived"), notice: "Teklif geri yüklendi."
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "offers/standart#restore")
    redirect_to offers_standart_index_path(scope: "archived"), alert: "Teklif geri yüklenemedi: #{e.user_message}"
  end

  def new
    if params[:offer_id].present?
      load_offer_for_continue!(params[:offer_id].to_s)
    else
      draft_id = create_draft_offer!(
        company_id: params[:company_id].to_s,
        project: params[:project].to_s,
        offer_type: "standard"
      )
      clear_offer_caches!
      redirect_to new_offers_standart_path(offer_id: draft_id) and return
    end

    @selected_category_id = params[:category_id].to_s.presence
    @items = [default_item]
    load_form_data(category_id: @selected_category_id)
  rescue Supabase::Client::ConfigurationError
    @companies = []
    @products = []
    @category_options = []
    @category_labels = {}
    @currencies = []
    @company_name ||= "Yuklenemedi"
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "offers/standart#new")
    has_flow_params = params[:offer_id].present? || params[:company_id].present? || params[:project].present?
    unless has_flow_params
      redirect_to offers_standart_index_path, alert: e.user_message and return
    end

    flash.now[:alert] = e.user_message
    @offer ||= {}
    @offer["id"] ||= ""
    @offer["company_id"] ||= params[:company_id].to_s
    @offer["offer_number"] ||= "PRJ-#{Date.current.strftime('%Y%m%d')}-#{SecureRandom.hex(2).upcase}"
    @offer["offer_date"] ||= Date.current.iso8601
    @offer["status"] ||= "taslak"
    @offer["project"] ||= params[:project].to_s
    @offer["offer_type"] ||= "standard"
    @selected_category_id = params[:category_id].to_s.presence
    @items = [default_item]
    load_form_data(category_id: @selected_category_id)
    resolve_company_name
    render :new, status: :unprocessable_entity
  end
  def create
    permitted = offer_params.to_h
    @selected_category_id = permitted.delete("product_category_id").to_s.presence
    permitted["items"] = Array(permitted["items"]).map { |item| item.to_h.deep_symbolize_keys }
    payload = Offers::CreateForm.new(permitted).normalized_attributes

    if permitted["id"].present?
      offer_id = finalize_existing_offer!(offer_id: permitted["id"].to_s, payload: payload)
    else
      offer_id = Sales::UseCases::Offers::Create.new(client: supabase_user_client).call(payload: payload, user_id: current_user.id)
    end

    clear_offer_caches!
    redirect_to offers_standart_path(offer_id), notice: "Teklif olusturuldu."
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "offers/standart#create")
    flash.now[:alert] = "Teklif olusturulamadi: #{e.user_message}"
    @offer = payload.except(:items).stringify_keys
    @offer["id"] = permitted["id"].to_s if defined?(permitted) && permitted.is_a?(Hash)
    @items = payload[:items]
    load_form_data(category_id: @selected_category_id)
    resolve_company_name
    render :new, status: :unprocessable_entity
  rescue Supabase::Client::ConfigurationError
    flash.now[:alert] = "Teklif formu yuklenemedi."
    @offer = payload&.except(:items)&.stringify_keys || {}
    @items = payload&.[](:items) || [default_item]
    @companies = []
    @products = []
    @category_options = []
    @category_labels = {}
    @currencies = []
    @company_name = "Yuklenemedi"
    render :new, status: :unprocessable_entity
  end
  private

  def offer_params
    params.require(:offer).permit(
      :company_id,
      :id,
      :offer_number,
      :offer_date,
      :status,
      :project,
      :offer_type,
      :product_category_id,
      items: %i[product_id description quantity unit_price discount_rate]
    )
  end

  def load_form_data(category_id:)
    query = Offers::FormQuery.new(client: supabase_user_client)
    @companies = Companies::OptionsQuery.new(client: supabase_user_client).call(active_only: true, user_id: current_user.id)
    @products = query.products(category_id: category_id, user_id: current_user.id)
    category_rows = Categories::OptionsQuery.new(client: supabase_user_client).call(active_only: true, user_id: current_user.id)
    @category_options = category_rows.map { |row| [row["name"].to_s, row["id"].to_s] }
    @category_labels = category_rows.each_with_object({}) { |row, hash| hash[row["id"].to_s] = row["name"].to_s }
    @currencies = Currencies::OptionsQuery.new(client: supabase_user_client).call(active_only: true, user_id: current_user.id)
  rescue ServiceErrors::System => e
    report_handled_error(e, source: "offers/standart#load_form_data", severity: :error)
    flash.now[:alert] ||= e.user_message
    @companies = []
    @products = []
    @category_options = []
    @category_labels = {}
    @currencies = []
  rescue StandardError
    @companies = []
    @products = []
    @category_options = []
    @category_labels = {}
    @currencies = []
  end

  def resolve_company_name
    cid = @offer&.dig("company_id").to_s
    if cid.present? && Array(@companies).any?
      found = @companies.find { |c| c["id"].to_s == cid }
      @company_name = found ? found["name"] : "Bilinmeyen Müşteri"
    else
      @company_name ||= "Müşteri Seçilmedi"
    end
  end

  def create_draft_offer!(company_id:, project:, offer_type:)
    cid = company_id.to_s
    raise ServiceErrors::Validation.new(user_message: "Musteri secimi zorunludur.") if cid.blank?

    generated_offer_number = "PRJ-#{Date.current.strftime('%Y%m%d')}-#{SecureRandom.hex(2).upcase}"
    payload = {
      user_id: current_user.id,
      company_id: cid,
      offer_number: generated_offer_number,
      offer_date: Date.current.iso8601,
      status: "taslak",
      net_total: 0,
      vat_total: 0,
      gross_total: 0,
      project: project.to_s.strip.presence || "Belirtilmedi",
      offer_type: offer_type.to_s.presence || "standard"
    }

    created = supabase_user_client.post("offers", body: payload, headers: { "Prefer" => "return=representation" })
    draft_id = extract_inserted_offer_id(created)

    # Some configurations allow insert but do not return inserted rows.
    # Resolve the created draft id by querying with the generated offer number.
    if draft_id.blank?
      path = "offers?" \
             "offer_number=eq.#{Supabase::FilterValue.eq(generated_offer_number)}&" \
             "deleted_at=is.null&" \
             "select=id&order=created_at.desc&limit=1"
      rows = supabase_user_client.get(path)
      fallback_row = rows.is_a?(Array) ? rows.first : nil
      draft_id = fallback_row.is_a?(Hash) ? fallback_row["id"].to_s : ""
    end

    raise ServiceErrors::System.new(user_message: "Taslak teklif olusturulamadi.") if draft_id.blank?

    draft_id
  end

  def extract_inserted_offer_id(created_payload)
    return "" if created_payload.nil?

    if created_payload.is_a?(Array)
      row = created_payload.first
      return row["id"].to_s if row.is_a?(Hash) && row["id"].present?
    end

    if created_payload.is_a?(Hash)
      return created_payload["id"].to_s if created_payload["id"].present?

      data = created_payload["data"]
      if data.is_a?(Array)
        row = data.first
        return row["id"].to_s if row.is_a?(Hash) && row["id"].present?
      elsif data.is_a?(Hash)
        return data["id"].to_s if data["id"].present?
      end
    end

    ""
  end

  def load_offer_for_continue!(offer_id)
    path = "offers?id=eq.#{Supabase::FilterValue.eq(offer_id)}" \
           "&deleted_at=is.null" \
           "&offer_items.deleted_at=is.null" \
           "&select=id,company_id,offer_number,offer_date,status,project,offer_type,companies(name),offer_items(id,product_id,description,quantity,unit_price,discount_rate,line_total)"
    rows = supabase_user_client.get(path)
    row = rows.is_a?(Array) ? rows.first : nil
    raise ServiceErrors::System.new(user_message: "Teklif bulunamadi.") unless row.is_a?(Hash)

    @offer = {
      "id" => row["id"].to_s,
      "company_id" => row["company_id"].to_s,
      "offer_number" => row["offer_number"].to_s,
      "offer_date" => row["offer_date"].to_s,
      "status" => row["status"].to_s.presence || "taslak",
      "project" => row["project"].to_s,
      "offer_type" => row["offer_type"].to_s.presence || "standard"
    }
    @company_name = row.dig("companies", "name").to_s.presence || "Bilinmeyen Musteri"
  end

  def finalize_existing_offer!(offer_id:, payload:)
    form = Offers::CreateForm.new(payload)
    unless form.valid?
      raise ServiceErrors::Validation.new(user_message: form.errors.full_messages.join(", "))
    end

    normalized = form.normalized_attributes
    items = normalized.delete(:items)

    repository = Offers::Repository.new(client: supabase_user_client)
    product_map = repository.fetch_products(items.map { |i| i[:product_id] })
    built_items = Offers::ItemBuilder.new(product_map).build(items)
    raise ServiceErrors::Validation.new(user_message: "Kalemler gecersiz.") if built_items.empty?

    totals = Offers::TotalsCalculator.new.call(built_items)
    now_iso = Time.now.utc.iso8601

    supabase_user_client.patch(
      "offers?id=eq.#{Supabase::FilterValue.eq(offer_id)}&user_id=eq.#{Supabase::FilterValue.eq(current_user.id)}&deleted_at=is.null",
      body: {
        company_id: normalized[:company_id],
        offer_number: normalized[:offer_number],
        offer_date: normalized[:offer_date],
        status: Offers::Status.normalize(normalized[:status]),
        project: normalized[:project],
        offer_type: normalized[:offer_type],
        net_total: totals[:net_total].to_s,
        vat_total: totals[:vat_total].to_s,
        gross_total: totals[:gross_total].to_s,
        updated_at: now_iso
      },
      headers: { "Prefer" => "return=representation" }
    )

    supabase_user_client.patch(
      "offer_items?offer_id=eq.#{Supabase::FilterValue.eq(offer_id)}&user_id=eq.#{Supabase::FilterValue.eq(current_user.id)}&deleted_at=is.null",
      body: { deleted_at: now_iso, updated_at: now_iso }
    )

    item_rows = built_items.map do |item|
      {
        user_id: current_user.id,
        offer_id: offer_id,
        product_id: item[:product_id],
        description: item[:description],
        quantity: item[:quantity].to_s,
        unit_price: item[:unit_price].to_s,
        discount_rate: item[:discount_rate].to_s,
        line_total: item[:line_total].to_s
      }
    end
    supabase_user_client.post("offer_items", body: item_rows, headers: { "Prefer" => "return=minimal" })

    offer_id
  end
  def default_item
    { product_id: "", description: "", quantity: "1", unit_price: "", discount_rate: "0" }
  end

  def authorize_offers!
    authorize_with_policy!(OffersPolicy)
  end

  def clear_offer_caches!
    QueryCacheInvalidator.new.invalidate_offers!(user_id: current_user.id)
  end
end
