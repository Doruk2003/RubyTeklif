require "digest"

module Products
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
      data = @client.get(build_query(params, page: page, per_page: per_page))
      rows = data.is_a?(Array) ? data : []

      {
        items: rows.first(per_page),
        scope: normalized_scope(params),
        page: page,
        per_page: per_page,
        has_prev: page > 1,
        has_next: rows.size > per_page
      }
    end

    def cache_key(params, user_id:)
      filtered = {
        page: page(params),
        per_page: per_page(params),
        scope: normalized_scope(params),
        category: params[:category].to_s
      }

      "queries/products/v1/user:#{user_id}/#{Digest::SHA256.hexdigest(filtered.to_json)}"
    end

    def build_query(params, page:, per_page:)
      filters = [deleted_scope_filter(params)].compact
      if params[:category].present?
        filters << "category_id=eq.#{Supabase::FilterValue.eq(params[:category])}"
      end

      base = "products?select=id,sku,name,description,barcode,category_id,brand_id,currency_id,price,cost_price,stock_quantity,min_stock_level,vat_rate,item_type,unit,is_stock_item,sale_price_vat_included,cost_price_vat_included,active,deleted_at,categories(name),brands(name),currencies(code,name,symbol)&order=created_at.desc"
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
