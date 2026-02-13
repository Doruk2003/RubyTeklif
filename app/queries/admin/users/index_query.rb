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

      private

      def build_query(params, page:, per_page:)
        offset = (page - 1) * per_page
        base = "users?select=id,email,role,active&order=email.asc"
        filters = []

        if params[:q].present?
          q = params[:q].to_s.strip
          filters << "email=ilike.*#{q}*"
        end
        filters << "role=eq.#{params[:role]}" if params[:role].present?
        filters << "active=eq.#{params[:active]}" if params[:active].present?

        query = filters.empty? ? base : "#{base}&#{filters.join('&')}"
        "#{query}&limit=#{per_page + 1}&offset=#{offset}"
      end

      def positive_int(value, default:, max: nil)
        parsed = value.to_i
        parsed = default if parsed <= 0
        return parsed unless max

        [parsed, max].min
      end
    end
  end
end

