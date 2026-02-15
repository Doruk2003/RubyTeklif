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
      deleted_filter = scope_filter(scope)
      path = "categories?select=id,code,name,active,deleted_at&order=name.asc&limit=#{per_page + 1}&offset=#{(page - 1) * per_page}"
      path = "categories?#{deleted_filter}&select=id,code,name,active,deleted_at&order=name.asc&limit=#{per_page + 1}&offset=#{(page - 1) * per_page}" if deleted_filter.present?
      data = @client.get(path)
      rows = data.is_a?(Array) ? data : []

      {
        items: rows.first(per_page),
        scope: scope,
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
  end
end
