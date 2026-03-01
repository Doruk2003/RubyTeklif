module Offers
  class IndexQuery
    DEFAULT_PER_PAGE = 50
    MAX_PER_PAGE = 200

    def initialize(client:)
      @client = client
    end

    def call(params:)
      page = page(params)
      per_page = per_page(params)
      data = @client.get(build_query(params, page: page, per_page: per_page))
      unless data.is_a?(Array)
        raise ServiceErrors::System.new(user_message: "Teklif listesi gecici olarak yuklenemedi. Lutfen tekrar deneyin.")
      end
      rows = data

      {
        items: rows.first(per_page),
        scope: normalized_scope(params),
        page: page,
        per_page: per_page,
        has_prev: page > 1,
        has_next: rows.size > per_page
      }
    end

    private

    def per_page(params)
      raw = params[:per_page].to_i
      return DEFAULT_PER_PAGE if raw <= 0

      [raw, MAX_PER_PAGE].min
    end

    def page(params)
      raw = params[:page].to_i
      raw.positive? ? raw : 1
    end

    def build_query(params, page:, per_page:)
      filters = [
        deleted_scope_filter(params),
        type_filter(params),
        company_filter(params),
        project_filter(params),
        date_filter(params),
        status_filter(params)
      ].compact
      base = "offers?select=id,project,offer_type,offer_number,offer_date,gross_total,status,deleted_at,companies(name)&order=offer_date.desc"
      query = filters.empty? ? base : "#{base}&#{filters.join('&')}"
      "#{query}&limit=#{per_page + 1}&offset=#{(page - 1) * per_page}"
    end

    def type_filter(params)
      type = params[:offer_type].to_s
      return nil if type.blank?

      "offer_type=eq.#{Supabase::FilterValue.eq(type)}"
    end

    def company_filter(params)
      company_id = params[:company_id].to_s
      return nil if company_id.blank?

      "company_id=eq.#{Supabase::FilterValue.eq(company_id)}"
    end

    def project_filter(params)
      project = params[:project].to_s.strip
      return nil if project.blank?

      "project=ilike.*#{Supabase::FilterValue.ilike(project)}*"
    end

    def date_filter(params)
      date = params[:offer_date].to_s
      return nil if date.blank?

      "offer_date=eq.#{Supabase::FilterValue.eq(date)}"
    end

    def status_filter(params)
      status = params[:status].to_s
      return nil if status.blank?

      "status=eq.#{Supabase::FilterValue.eq(status)}"
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
  end
end
