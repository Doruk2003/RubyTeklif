require "cgi"

module Categories
  class IndexQuery
    DEFAULT_PER_PAGE = 50
    MAX_PER_PAGE = 200

    def initialize(client:)
      @client = client
    end

    def call(params:)
      page = page(params)
      per_page = per_page(params)
      scope = scope(params)
      active = active(params)
      q = q(params)
      sort = sort(params)
      dir = dir(params)
      deleted_filter = scope_filter(scope)
      active_filter_value = active_filter(active)
      q_filter_value = q_filter(q)
      filters = []
      filters << deleted_filter if deleted_filter.present?
      filters << active_filter_value if active_filter_value.present?
      filters << q_filter_value if q_filter_value.present?

      path = "categories?#{filters.join('&')}"
      path = "categories?" if filters.empty?
      path += "#{filters.any? ? '&' : ''}select=id,code,name,active,deleted_at"
      path += "&order=#{sort}.#{dir}"
      path += "&limit=#{per_page + 1}&offset=#{(page - 1) * per_page}"
      data = @client.get(path)
      rows = data.is_a?(Array) ? data : []

      {
        items: rows.first(per_page),
        scope: scope,
        active: active,
        q: q,
        sort: sort,
        dir: dir,
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

    def scope(params)
      value = params[:scope].to_s
      return "archived" if value == "archived"
      return "all" if value == "all"

      "active"
    end

    def scope_filter(value)
      case value
      when "archived"
        "deleted_at=not.is.null"
      else
        value == "active" ? "deleted_at=is.null" : nil
      end
    end

    def active(params)
      value = params[:active].to_s
      return "1" if value == "1"
      return "0" if value == "0"

      ""
    end

    def active_filter(value)
      return "active=eq.true" if value == "1"
      return "active=eq.false" if value == "0"

      nil
    end

    def q(params)
      params[:q].to_s.strip
    end

    def q_filter(value)
      return nil if value.blank?

      encoded = CGI.escape(value).gsub("+", "%20")
      "or=(name.ilike.*#{encoded}*,code.ilike.*#{encoded}*)"
    end

    def sort(params)
      allowed = %w[name code active]
      value = params[:sort].to_s
      allowed.include?(value) ? value : "name"
    end

    def dir(params)
      params[:dir].to_s == "desc" ? "desc" : "asc"
    end
  end
end
