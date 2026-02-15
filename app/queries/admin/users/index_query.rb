module Admin
  module Users
    class IndexQuery
      DEFAULT_PER_PAGE = 100
      MAX_PER_PAGE = 200

      def initialize(client:)
        @client = client
      end

      def call(params:)
        page = positive_int(params[:page], default: 1)
        per_page = positive_int(params[:per_page], default: DEFAULT_PER_PAGE, max: MAX_PER_PAGE)
        rows = @client.get(build_query(params, page: page, per_page: per_page))
        rows = rows.is_a?(Array) ? rows : []

        {
          items: rows.first(per_page),
          page: page,
          per_page: per_page,
          has_prev: page > 1,
          has_next: rows.size > per_page
        }
      end

      def export_rows(params:, max_rows: 5_000)
        limit = [ max_rows.to_i, 10_000 ].min
        base = "users?select=id,email,role,active&order=email.asc&limit=#{limit}&offset=0"
        query = append_filters(base, params)
        rows = @client.get(query)
        rows.is_a?(Array) ? rows : []
      rescue StandardError
        []
      end

      private

      def build_query(params, page:, per_page:)
        offset = (page - 1) * per_page
        base = "users?select=id,email,role,active&order=email.asc"
        query = append_filters(base, params)
        "#{query}&limit=#{per_page + 1}&offset=#{offset}"
      end

      def append_filters(base_query, params)
        filters = build_filters(params)
        filters.empty? ? base_query : "#{base_query}&#{filters.join('&')}"
      end

      def build_filters(params)
        filters = []

        if params[:q].present?
          q = params[:q].to_s.strip
          filters << "email=ilike.*#{Supabase::FilterValue.ilike(q)}*"
        end
        filters << "role=eq.#{Supabase::FilterValue.eq(params[:role])}" if params[:role].present?
        filters << "active=eq.#{Supabase::FilterValue.eq(params[:active])}" if params[:active].present?
        filters
      end

      def positive_int(value, default:, max: nil)
        parsed = value.to_i
        parsed = default if parsed <= 0
        return parsed unless max

        [ parsed, max ].min
      end
    end
  end
end
