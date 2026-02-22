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
        unless rows.is_a?(Array)
          raise ServiceErrors::System.new(user_message: "Aktivite kayitlari gecici olarak yuklenemedi. Lutfen tekrar deneyin.")
        end

        {
          items: rows.first(per_page),
          page: page,
          per_page: per_page,
          has_prev: page > 1,
          has_next: rows.size > per_page
        }
      end

      def action_options
        load_filter_options[:actions]
      end

      def target_type_options
        load_filter_options[:target_types]
      end

      def export_rows(params:, max_rows: 5_000)
        limit = [ max_rows.to_i, 10_000 ].min
        base = "activity_logs?select=id,action,actor_id,target_id,target_type,metadata,created_at&order=created_at.desc&limit=#{limit}&offset=0"
        query = append_filters(base, params)
        rows = @client.get(query)
        return rows if rows.is_a?(Array)

        raise ServiceErrors::System.new(user_message: "Aktivite export verisi gecici olarak yuklenemedi. Lutfen tekrar deneyin.")
      rescue StandardError => e
        raise if e.is_a?(ServiceErrors::Base)

        raise ServiceErrors::System.new(user_message: "Aktivite export verisi gecici olarak yuklenemedi. Lutfen tekrar deneyin.")
      end

      private

      def build_query(params, page:, per_page:)
        offset = (page - 1) * per_page
        base = "activity_logs?select=id,action,actor_id,target_id,target_type,metadata,created_at&order=created_at.desc&limit=#{per_page + 1}&offset=#{offset}"
        append_filters(base, params)
      end

      def append_filters(base_query, params)
        filters = build_filters(params)
        filters.empty? ? base_query : "#{base_query}&#{filters.join('&')}"
      end

      def build_filters(params)
        filters = []
        action_filter = params[:event_action].presence || params[:action].presence
        filters << "action=eq.#{Supabase::FilterValue.eq(action_filter)}" if action_filter.present?
        filters << "actor_id=eq.#{Supabase::FilterValue.eq(params[:actor])}" if params[:actor].present?
        filters << "target_id=eq.#{Supabase::FilterValue.eq(params[:target])}" if params[:target].present?
        filters << "target_type=eq.#{Supabase::FilterValue.eq(params[:target_type])}" if params[:target_type].present?
        filters << "created_at=gte.#{Supabase::FilterValue.eq(params[:from])}" if params[:from].present?
        filters << "created_at=lte.#{Supabase::FilterValue.eq(params[:to])}" if params[:to].present?
        filters
      end

      def positive_int(value, default:, max: nil)
        parsed = value.to_i
        parsed = default if parsed <= 0
        return parsed unless max

        [ parsed, max ].min
      end

      def load_filter_options
        return @filter_options if defined?(@filter_options)

        rows = @client.get("activity_logs?select=action,target_type&order=created_at.desc&limit=500")
        unless rows.is_a?(Array)
          raise ServiceErrors::System.new(user_message: "Aktivite filtre verileri gecici olarak yuklenemedi. Lutfen tekrar deneyin.")
        end
        @filter_options = {
          actions: rows.map { |row| row["action"].to_s }.reject(&:blank?).uniq,
          target_types: rows.map { |row| row["target_type"].to_s }.reject(&:blank?).uniq
        }
      rescue StandardError => e
        raise if e.is_a?(ServiceErrors::Base)

        raise ServiceErrors::System.new(user_message: "Aktivite filtre verileri gecici olarak yuklenemedi. Lutfen tekrar deneyin.")
      end
    end
  end
end
