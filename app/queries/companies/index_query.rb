require "digest"

module Companies
  class IndexQuery
    DEFAULT_PER_PAGE = 50
    MAX_PER_PAGE = 200

    def initialize(client:)
      @client = client
    end

    def call(params:, user_id: nil)
      return build_result(params) unless user_id.present?

      Rails.cache.fetch(cache_key(params, user_id: user_id), expires_in: 90.seconds) do
        build_result(params)
      end
    end

    private

    def build_result(params)
      page = page(params)
      per_page = per_page(params)
      rows = fetch_companies(params)
      has_next = rows.size > per_page
      rows = rows.first(per_page)
      company_ids = rows.map { |row| row["id"].to_s }.reject(&:blank?)
      offer_counts = needs_offer_counts?(params) ? load_offer_counts(company_ids) : Hash.new(0)

      companies = rows.map do |row|
        build_company(row, offers_count: offer_counts[row["id"]].to_i)
      end

      companies = apply_has_offers_filter(companies, params) if params[:has_offers].present?
      companies = apply_offers_count_sort(companies, params)

      {
        items: companies,
        scope: normalized_scope(params),
        page: page,
        per_page: per_page,
        has_prev: page > 1,
        has_next: has_next
      }
    end

    def cache_key(params, user_id:)
      filtered = {
        page: page(params),
        per_page: per_page(params),
        scope: normalized_scope(params),
        q: params[:q].to_s.strip,
        tax_number: params[:tax_number].to_s.strip,
        phone: params[:phone].to_s.strip,
        active: params[:active].to_s,
        has_offers: params[:has_offers].to_s,
        sort: params[:sort].to_s,
        dir: params[:dir].to_s
      }

      "queries/companies/v1/user:#{user_id}/#{Digest::SHA256.hexdigest(filtered.to_json)}"
    end

    def fetch_companies(params)
      @client.get(build_companies_query(params)).tap do |data|
        return data if data.is_a?(Array)
      end
      []
    rescue StandardError
      []
    end

    def build_companies_query(params)
      query_parts = []
      query_parts << "select=id,name,tax_number,tax_office,authorized_person,phone,email,address,active,deleted_at"
      query_parts << sort_clause(params)
      query_parts << "limit=#{per_page(params) + 1}"
      query_parts << "offset=#{offset(params)}"

      q = params[:q].to_s.strip
      if q.present?
        escaped = escape_like_value(q)
        query_parts << "or=(name.ilike.*#{escaped}*,authorized_person.ilike.*#{escaped}*,email.ilike.*#{escaped}*)"
      end

      tax_number = params[:tax_number].to_s.strip
      query_parts << "tax_number=ilike.*#{escape_like_value(tax_number)}*" if tax_number.present?

      phone = params[:phone].to_s.strip
      query_parts << "phone=ilike.*#{escape_like_value(phone)}*" if phone.present?

      if params[:active].present?
        active = params[:active].to_s == "1"
        query_parts << "active=eq.#{active}"
      end

      query_parts << deleted_scope_filter(params)

      "companies?#{query_parts.compact.join('&')}"
    end

    def sort_clause(params)
      sort = params[:sort].to_s
      dir = params[:dir].to_s == "asc" ? "asc" : "desc"

      allowed = {
        "name" => "name",
        "authorized_person" => "authorized_person",
        "phone" => "phone",
        "email" => "email",
        "tax_number" => "tax_number",
        "tax_office" => "tax_office",
        "active" => "active"
      }

      column = allowed[sort] || "created_at"
      "order=#{column}.#{dir}"
    end

    def per_page(params)
      raw = params[:per_page].to_i
      return DEFAULT_PER_PAGE if raw <= 0

      [raw, MAX_PER_PAGE].min
    end

    def page(params)
      raw = params[:page].to_i
      raw.positive? ? raw : 1
    end

    def offset(params)
      (page(params) - 1) * per_page(params)
    end

    def normalized_scope(params)
      scope = params[:scope].to_s
      return "archived" if scope == "archived"
      return "all" if scope == "all"

      "active"
    end

    def deleted_scope_filter(params)
      case normalized_scope(params)
      when "archived"
        "deleted_at=not.is.null"
      when "all"
        nil
      else
        "deleted_at=is.null"
      end
    end

    def escape_like_value(value)
      value.to_s.gsub("%", "\\%").gsub("_", "\\_")
    end

    def needs_offer_counts?(params)
      params[:has_offers].present? || params[:sort].to_s == "offers_count"
    end

    def load_offer_counts(company_ids)
      return Hash.new(0) if company_ids.empty?

      encoded_ids = company_ids.map { |id| Supabase::FilterValue.eq(id) }.join(",")
      data = @client.get("company_offer_stats?select=company_id,offers_count&company_id=in.(#{encoded_ids})")
      rows = data.is_a?(Array) ? data : []

      rows.each_with_object(Hash.new(0)) do |row, counts|
        company_id = row["company_id"].to_s
        next if company_id.blank?

        count = row["offers_count"].to_i
        counts[company_id] = count
      end
    rescue StandardError
      load_offer_counts_fallback(company_ids)
    end

    def load_offer_counts_fallback(company_ids)
      return Hash.new(0) if company_ids.empty?

      encoded_ids = company_ids.map { |id| Supabase::FilterValue.eq(id) }.join(",")
      data = @client.get("offers?select=company_id&deleted_at=is.null&company_id=in.(#{encoded_ids})")
      rows = data.is_a?(Array) ? data : []

      rows.each_with_object(Hash.new(0)) do |row, counts|
        company_id = row["company_id"].to_s
        counts[company_id] += 1 if company_id.present?
      end
    rescue StandardError
      Hash.new(0)
    end

    def apply_has_offers_filter(companies, params)
      has_offers = params[:has_offers].to_s == "1"
      companies.select do |company|
        has_offers ? company.offers_count.to_i.positive? : company.offers_count.to_i.zero?
      end
    end

    def apply_offers_count_sort(companies, params)
      return companies unless params[:sort].to_s == "offers_count"

      dir = params[:dir].to_s == "asc" ? "asc" : "desc"
      sorted = companies.sort_by { |company| company.offers_count.to_i }
      dir == "asc" ? sorted : sorted.reverse
    end

    def build_company(row, offers_count: 0)
      Company.new(
        id: row["id"],
        name: row["name"],
        tax_number: row["tax_number"],
        tax_office: row["tax_office"],
        authorized_person: row["authorized_person"],
        phone: row["phone"],
        email: row["email"],
        address: row["address"],
        active: row.key?("active") ? row["active"] : true,
        deleted_at: row["deleted_at"],
        offers_count: offers_count
      )
    end
  end
end

