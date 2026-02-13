module Admin
  module ActivityLogs
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

      def action_options
        rows = @client.get("activity_logs?select=action&order=action.asc&limit=500")
        rows = rows.is_a?(Array) ? rows : []
        rows.map { |row| row["action"].to_s }.reject(&:blank?).uniq
      rescue StandardError
        []
      end

      private

      def build_query(params, page:, per_page:)
        offset = (page - 1) * per_page
        base = "activity_logs?select=id,action,actor_id,target_id,target_type,metadata,created_at&order=created_at.desc&limit=#{per_page + 1}&offset=#{offset}"
        filters = []
        filters << "action=eq.#{params[:action]}" if params[:action].present?
        filters << "actor_id=eq.#{params[:actor]}" if params[:actor].present?
        filters << "target_id=eq.#{params[:target]}" if params[:target].present?
        filters << "created_at=gte.#{params[:from]}" if params[:from].present?
        filters << "created_at=lte.#{params[:to]}" if params[:to].present?
        filters.empty? ? base : "#{base}&#{filters.join('&')}"
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

