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

      Rails.cache.fetch(cache_key(params, user_id: user_id), expires_in: 30.seconds) do
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
      companies = rows.map { |row| build_company(row) }

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
        city: params[:city].to_s.strip,
        country: params[:country].to_s.strip,
        phone: params[:phone].to_s.strip,
        active: params[:active].to_s,
        has_offers: params[:has_offers].to_s,
        sort: params[:sort].to_s,
        dir: params[:dir].to_s
      }

      "queries/companies/v2/user:#{user_id}/#{Digest::SHA256.hexdigest(filtered.to_json)}"
    end

    def fetch_companies(params)
      data = @client.get(build_companies_query(params))
      return data if data.is_a?(Array)

      raise ServiceErrors::System.new(user_message: "Musteri listesi gecici olarak yuklenemedi. Lutfen tekrar deneyin.")
    rescue StandardError => e
      raise if e.is_a?(ServiceErrors::Base)

      raise ServiceErrors::System.new(user_message: "Musteri listesi gecici olarak yuklenemedi. Lutfen tekrar deneyin.")
    end

    def build_companies_query(params)
      query_parts = []
      query_parts << "select=id,name,tax_number,tax_office,authorized_person,phone,email,address,description,city,country,active,deleted_at,offers_count"
      query_parts << sort_clause(params)
      query_parts << "limit=#{per_page(params) + 1}"
      query_parts << "offset=#{offset(params)}"

      q = params[:q].to_s.strip
      if q.present?
        escaped = escape_like_value(q)
        query_parts << "or=(name.ilike.*#{escaped}*,authorized_person.ilike.*#{escaped}*,email.ilike.*#{escaped}*)"
      end

      city = params[:city].to_s.strip
      query_parts << "city=ilike.*#{escape_like_value(city)}*" if city.present?

      country = params[:country].to_s.strip
      query_parts << "country=ilike.*#{escape_like_value(country)}*" if country.present?

      phone = params[:phone].to_s.strip
      query_parts << "phone=ilike.*#{escape_like_value(phone)}*" if phone.present?

      if params[:active].present?
        active = params[:active].to_s == "1"
        query_parts << "active=eq.#{active}"
      end

      if params[:has_offers].present?
        has_offers = params[:has_offers].to_s == "1"
        query_parts << (has_offers ? "offers_count=gt.0" : "offers_count=eq.0")
      end

      query_parts << deleted_scope_filter(params)

      "company_with_offer_counts?#{query_parts.compact.join('&')}"
    end

    def sort_clause(params)
      sort = params[:sort].to_s
      dir = params[:dir].to_s == "asc" ? "asc" : "desc"

      allowed = {
        "name" => "name",
        "authorized_person" => "authorized_person",
        "phone" => "phone",
        "email" => "email",
        "city" => "city",
        "country" => "country",
        "tax_number" => "tax_number",
        "tax_office" => "tax_office",
        "active" => "active",
        "offers_count" => "offers_count"
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

    def build_company(row)
      Company.new(
        id: row["id"],
        name: row["name"],
        tax_number: row["tax_number"],
        tax_office: row["tax_office"],
        authorized_person: row["authorized_person"],
        phone: row["phone"],
        email: row["email"],
        address: row["address"],
        description: row["description"],
        city: row["city"],
        country: row["country"],
        active: row.key?("active") ? row["active"] : true,
        deleted_at: row["deleted_at"],
        offers_count: row["offers_count"].to_i
      )
    end
  end
end
