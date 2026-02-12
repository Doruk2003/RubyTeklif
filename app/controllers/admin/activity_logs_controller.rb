module Admin
  class ActivityLogsController < ApplicationController
    before_action :authorize_admin!

    def index
      query = build_query
      data = client.get(query)
      @logs = data.is_a?(Array) ? data : []
      @users_index = load_users_index
    rescue Supabase::Client::ConfigurationError
      @logs = []
      @users_index = {}
    end

    private

    def client
      @client ||= Supabase::Client.new(role: :service)
    end

    def authorize_admin!
      require_role!(Roles::ADMIN)
    end

    def build_query
      base = "activity_logs?select=id,action,actor_id,target_id,metadata,created_at&order=created_at.desc&limit=200"
      filters = []
      if params[:action].present?
        filters << "action=eq.#{params[:action]}"
      end
      if params[:actor].present?
        filters << "actor_id=eq.#{params[:actor]}"
      end
      if params[:target].present?
        filters << "target_id=eq.#{params[:target]}"
      end
      if params[:from].present?
        filters << "created_at=gte.#{params[:from]}"
      end
      if params[:to].present?
        filters << "created_at=lte.#{params[:to]}"
      end
      filters.empty? ? base : "#{base}&#{filters.join('&')}"
    end

    def load_users_index
      data = client.get("users?select=id,email&order=email.asc")
      return {} unless data.is_a?(Array)

      data.each_with_object({}) do |row, acc|
        acc[row["id"].to_s] = row["email"].to_s
      end
    end
  end
end
