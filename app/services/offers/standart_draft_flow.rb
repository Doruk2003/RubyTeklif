require "bigdecimal"

class Offers::StandartDraftFlow
  def initialize(client:, user_id:)
    @client = client
    @user_id = user_id.to_s
  end

  def create_draft_offer!(company_id:, project:, offer_type:)
    cid = company_id.to_s
    raise ServiceErrors::Validation.new(user_message: "Musteri secimi zorunludur.") if cid.blank?

    generated_offer_number = next_daily_offer_number(date: Date.current)
    payload = {
      user_id: @user_id,
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

    created = @client.post("offers", body: payload, headers: { "Prefer" => "return=representation" })
    draft_id = extract_inserted_offer_id(created)

    if draft_id.blank?
      path = "offers?" \
             "offer_number=eq.#{Supabase::FilterValue.eq(generated_offer_number)}&" \
             "deleted_at=is.null&" \
             "select=id&order=created_at.desc&limit=1"
      rows = @client.get(path)
      fallback_row = rows.is_a?(Array) ? rows.first : nil
      draft_id = fallback_row.is_a?(Hash) ? fallback_row["id"].to_s : ""
    end

    raise ServiceErrors::System.new(user_message: "Taslak teklif olusturulamadi.") if draft_id.blank?

    draft_id
  end

  def load_offer_for_continue!(offer_id:)
    row = fetch_offer_row_with_retry(offer_id: offer_id)
    raise ServiceErrors::System.new(user_message: "Teklif bulunamadi.") unless row.is_a?(Hash)

    company_name = fetch_company_name(company_id: row["company_id"])
    active_items = fetch_active_offer_items(offer_id: offer_id)

    {
      offer: {
        "id" => row["id"].to_s,
        "company_id" => row["company_id"].to_s,
        "offer_number" => row["offer_number"].to_s,
        "offer_date" => row["offer_date"].to_s,
        "status" => row["status"].to_s.presence || "taslak",
        "project" => row["project"].to_s,
        "offer_type" => row["offer_type"].to_s.presence || "standard",
        "offer_items" => active_items
      },
      company_name: company_name.presence || "Bilinmeyen Musteri"
    }
  end

  def finalize_existing_offer!(offer_id:, payload:)
    form = Offers::CreateForm.new(payload)
    unless form.valid?
      raise ServiceErrors::Validation.new(user_message: form.errors.full_messages.join(", "))
    end

    normalized = form.normalized_attributes
    items = normalized.delete(:items)

    repository = Offers::Repository.new(client: @client)
    product_map = repository.fetch_products(items.map { |i| i[:product_id] })
    built_items = Offers::ItemBuilder.new(product_map).build(items)
    raise ServiceErrors::Validation.new(user_message: "Kalemler gecersiz.") if built_items.empty?

    totals = Offers::TotalsCalculator.new.call(built_items)
    now_iso = Time.now.utc.iso8601

    @client.patch(
      "offers?id=eq.#{Supabase::FilterValue.eq(offer_id)}&user_id=eq.#{Supabase::FilterValue.eq(@user_id)}&deleted_at=is.null",
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

    @client.patch(
      "offer_items?offer_id=eq.#{Supabase::FilterValue.eq(offer_id)}&user_id=eq.#{Supabase::FilterValue.eq(@user_id)}&deleted_at=is.null",
      body: { deleted_at: now_iso, updated_at: now_iso }
    )

    item_rows = built_items.map do |item|
      {
        user_id: @user_id,
        offer_id: offer_id,
        product_id: item[:product_id],
        description: item[:description],
        quantity: item[:quantity].to_s,
        unit_price: item[:unit_price].to_s,
        discount_rate: item[:discount_rate].to_s,
        line_total: item[:line_total].to_s
      }
    end
    @client.post("offer_items", body: item_rows, headers: { "Prefer" => "return=minimal" })

    offer_id
  end

  def sync_draft_items!(offer_id:, items:, update_offer_totals: false)
    oid = offer_id.to_s
    raise ServiceErrors::Validation.new(user_message: "Teklif secimi zorunludur.") if oid.blank?
    ensure_offer_owned!(offer_id: oid)

    normalized_items = normalize_sync_items(items)
    repository = Offers::Repository.new(client: @client)
    product_map = repository.fetch_products(normalized_items.map { |i| i[:product_id] })
    built_items = Offers::ItemBuilder.new(product_map).build(normalized_items)
    now_iso = Time.now.utc.iso8601

    @client.patch(
      "offer_items?offer_id=eq.#{Supabase::FilterValue.eq(oid)}&user_id=eq.#{Supabase::FilterValue.eq(@user_id)}&deleted_at=is.null",
      body: { deleted_at: now_iso, updated_at: now_iso }
    )

    if built_items.any?
      item_rows = built_items.map do |item|
        {
          user_id: @user_id,
          offer_id: oid,
          product_id: item[:product_id],
          description: item[:description],
          quantity: item[:quantity].to_s,
          unit_price: item[:unit_price].to_s,
          discount_rate: item[:discount_rate].to_s,
          line_total: item[:line_total].to_s
        }
      end
      @client.post("offer_items", body: item_rows, headers: { "Prefer" => "return=minimal" })
    end

    if update_offer_totals
      totals = Offers::TotalsCalculator.new.call(built_items)
      @client.patch(
        "offers?id=eq.#{Supabase::FilterValue.eq(oid)}&user_id=eq.#{Supabase::FilterValue.eq(@user_id)}&deleted_at=is.null",
        body: {
          net_total: totals[:net_total].to_s,
          vat_total: totals[:vat_total].to_s,
          gross_total: totals[:gross_total].to_s,
          updated_at: now_iso
        },
        headers: { "Prefer" => "return=minimal" }
      )
    end

    { items_count: built_items.size, saved_at: now_iso }
  end

  def apply_calculation!(offer_id:, totals:, status: "beklemede")
    oid = offer_id.to_s
    raise ServiceErrors::Validation.new(user_message: "Teklif secimi zorunludur.") if oid.blank?
    ensure_offer_owned!(offer_id: oid)

    now_iso = Time.now.utc.iso8601
    @client.patch(
      "offers?id=eq.#{Supabase::FilterValue.eq(oid)}&user_id=eq.#{Supabase::FilterValue.eq(@user_id)}&deleted_at=is.null",
      body: {
        status: Offers::Status.normalize(status),
        net_total: totals[:net_total].to_s,
        vat_total: totals[:vat_total].to_s,
        gross_total: totals[:gross_total].to_s,
        updated_at: now_iso
      },
      headers: { "Prefer" => "return=minimal" }
    )

    { saved_at: now_iso }
  end

  def add_extra_expense!(offer_id:, description:, unit:, quantity:, unit_price:, vat_rate:)
    oid = offer_id.to_s
    raise ServiceErrors::Validation.new(user_message: "Teklif secimi zorunludur.") if oid.blank?
    ensure_offer_owned!(offer_id: oid)

    qty = decimal(quantity)
    price = decimal(unit_price)
    vat = decimal(vat_rate)
    raise ServiceErrors::Validation.new(user_message: "Miktar 0'dan buyuk olmalidir.") unless qty.positive?
    raise ServiceErrors::Validation.new(user_message: "Birim fiyat negatif olamaz.") if price.negative?
    raise ServiceErrors::Validation.new(user_message: "KDV orani 0-100 arasinda olmalidir.") if vat.negative? || vat > decimal(100)

    item_line_total = qty * price
    item_vat_total = item_line_total * vat / decimal(100)
    item_gross_total = item_line_total + item_vat_total
    anchor_product_id = fetch_anchor_product_id(offer_id: oid)
    display_description = description.to_s.strip.presence || "Ek Masraf"
    row_description = build_expense_description(description: display_description, unit: unit, vat_rate: vat)
    now_iso = Time.now.utc.iso8601

    @client.post(
      "offer_items",
      body: {
        user_id: @user_id,
        offer_id: oid,
        product_id: anchor_product_id,
        description: row_description,
        quantity: qty.to_s("F"),
        unit_price: price.to_s("F"),
        discount_rate: "0",
        line_total: item_line_total.to_s("F"),
        created_at: now_iso,
        updated_at: now_iso
      },
      headers: { "Prefer" => "return=minimal" }
    )

    current_totals = fetch_offer_totals(offer_id: oid)
    updated_net = current_totals[:net_total] + item_line_total
    updated_vat = current_totals[:vat_total] + item_vat_total
    updated_gross = current_totals[:gross_total] + item_gross_total
    @client.patch(
      "offers?id=eq.#{Supabase::FilterValue.eq(oid)}&user_id=eq.#{Supabase::FilterValue.eq(@user_id)}&deleted_at=is.null",
      body: {
        net_total: updated_net.to_s("F"),
        vat_total: updated_vat.to_s("F"),
        gross_total: updated_gross.to_s("F"),
        updated_at: now_iso
      },
      headers: { "Prefer" => "return=minimal" }
    )

    {
      description: row_description,
      display_description: display_description,
      unit: unit.to_s.presence || "ADET",
      quantity: qty.to_s("F"),
      unit_price: price.to_s("F"),
      vat_rate: vat.to_s("F"),
      line_total: item_line_total.to_s("F"),
      vat_total: item_vat_total.to_s("F"),
      gross_total: item_gross_total.to_s("F"),
      offer_gross_total: updated_gross.to_s("F"),
      saved_at: now_iso
    }
  end

  private

  def next_daily_offer_number(date:)
    day = date.strftime("%Y%m%d")
    prefix = "PRJ-#{day}-"
    rows = fetch_same_day_offer_numbers(date: date)

    max_seq = Array(rows).filter_map do |row|
      number = row.is_a?(Hash) ? row["offer_number"].to_s : ""
      match = /\A#{Regexp.escape(prefix)}(\d{3,})\z/.match(number)
      match ? match[1].to_i : nil
    end.max.to_i

    "#{prefix}#{format('%03d', max_seq + 1)}"
  end

  def fetch_same_day_offer_numbers(date:)
    path = "offers?deleted_at=is.null" \
           "&offer_date=eq.#{Supabase::FilterValue.eq(date.iso8601)}" \
           "&select=offer_number&limit=500"
    rows = @client.get(path)
    rows.is_a?(Array) ? rows : []
  end

  def fetch_offer_row_with_retry(offer_id:)
    path = "offers?id=eq.#{Supabase::FilterValue.eq(offer_id)}" \
           "&deleted_at=is.null" \
           "&select=id,company_id,offer_number,offer_date,status,project,offer_type"

    attempts = 0
    loop do
      attempts += 1
      rows = @client.get(path)
      row = rows.is_a?(Array) ? rows.first : nil
      return row if row.is_a?(Hash)

      break if attempts >= 5

      sleep(0.12)
    end

    nil
  end

  def fetch_company_name(company_id:)
    cid = company_id.to_s
    return "" if cid.blank?

    path = "companies?id=eq.#{Supabase::FilterValue.eq(cid)}&deleted_at=is.null&select=name&limit=1"
    rows = @client.get(path)
    row = rows.is_a?(Array) ? rows.first : nil
    row.is_a?(Hash) ? row["name"].to_s : ""
  end

  def fetch_active_offer_items(offer_id:)
    path = "offer_items?offer_id=eq.#{Supabase::FilterValue.eq(offer_id)}" \
           "&deleted_at=is.null" \
           "&select=id,product_id,description,quantity,unit_price,discount_rate,line_total,deleted_at"
    rows = @client.get(path)
    return [] unless rows.is_a?(Array)

    rows.select { |item| item.is_a?(Hash) && item["deleted_at"].blank? }
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

  def ensure_offer_owned!(offer_id:)
    path = "offers?id=eq.#{Supabase::FilterValue.eq(offer_id)}" \
           "&user_id=eq.#{Supabase::FilterValue.eq(@user_id)}" \
           "&deleted_at=is.null&select=id&limit=1"
    rows = @client.get(path)
    row = rows.is_a?(Array) ? rows.first : nil
    return if row.is_a?(Hash) && row["id"].to_s.present?

    raise ServiceErrors::Validation.new(user_message: "Teklif bulunamadi.")
  end

  def normalize_sync_items(items)
    Array(items).map do |item|
      next unless item.is_a?(Hash)

      {
        product_id: item[:product_id].to_s,
        description: item[:description].to_s,
        quantity: item[:quantity].to_s,
        unit_price: item[:unit_price].to_s,
        discount_rate: item[:discount_rate].to_s
      }
    end.compact
  end

  def fetch_anchor_product_id(offer_id:)
    path = "offer_items?offer_id=eq.#{Supabase::FilterValue.eq(offer_id)}" \
           "&user_id=eq.#{Supabase::FilterValue.eq(@user_id)}" \
           "&deleted_at=is.null&select=product_id&order=created_at.asc&limit=1"
    rows = @client.get(path)
    row = rows.is_a?(Array) ? rows.first : nil
    product_id = row.is_a?(Hash) ? row["product_id"].to_s : ""
    return product_id if product_id.present?

    raise ServiceErrors::Validation.new(user_message: "Masraf eklemek icin en az bir teklif kalemi bulunmalidir.")
  end

  def fetch_offer_totals(offer_id:)
    path = "offers?id=eq.#{Supabase::FilterValue.eq(offer_id)}" \
           "&user_id=eq.#{Supabase::FilterValue.eq(@user_id)}" \
           "&deleted_at=is.null&select=net_total,vat_total,gross_total&limit=1"
    rows = @client.get(path)
    row = rows.is_a?(Array) ? rows.first : nil
    raise ServiceErrors::Validation.new(user_message: "Teklif bulunamadi.") unless row.is_a?(Hash)

    {
      net_total: decimal(row["net_total"]),
      vat_total: decimal(row["vat_total"]),
      gross_total: decimal(row["gross_total"])
    }
  end

  def build_expense_description(description:, unit:, vat_rate:)
    detail = description.to_s.strip.presence || "Ek Masraf"
    normalized_unit = unit.to_s.strip.upcase.presence || "ADET"
    normalized_vat = vat_rate.to_s("F")
    "[EXTRA MASRAF] #{detail} | Birim: #{normalized_unit} | KDV: %#{normalized_vat}"
  end

  def decimal(value)
    return BigDecimal("0") if value.nil?

    BigDecimal(value.to_s)
  rescue ArgumentError
    BigDecimal("0")
  end
end
