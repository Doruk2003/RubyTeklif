module Products
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
      rows = data.is_a?(Array) ? data : []

      {
        items: rows.first(per_page),
        page: page,
        per_page: per_page,
        has_prev: page > 1,
        has_next: rows.size > per_page
      }
    end

    private

    def build_query(params, page:, per_page:)
      filters = ["deleted_at=is.null"]
      filters << "category_id=eq.#{params[:category]}" if params[:category].present?

      base = "products?select=id,name,category_id,price,vat_rate,item_type,active,categories(name)&order=created_at.desc"
      query = filters.empty? ? base : "#{base}&#{filters.join('&')}"
      "#{query}&limit=#{per_page + 1}&offset=#{(page - 1) * per_page}"
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
  end
end
