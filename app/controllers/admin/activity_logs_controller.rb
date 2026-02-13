module Admin
  class ActivityLogsController < ApplicationController
    before_action :authorize_admin!

    def index
      query = Admin::ActivityLogs::IndexQuery.new(client: client)
      result = query.call(params: params)
      @logs = result[:items]
      @page = result[:page]
      @per_page = result[:per_page]
      @has_prev = result[:has_prev]
      @has_next = result[:has_next]
      @users_index = load_users_index
      @action_options = query.action_options
      @target_type_options = query.target_type_options
    rescue Supabase::Client::ConfigurationError
      @logs = []
      @users_index = {}
      @action_options = []
      @target_type_options = []
      @page = 1
      @per_page = 100
      @has_next = false
      @has_prev = false
    end

    private

    def client
      @client ||= Supabase::Client.new(role: :service)
    end

    def authorize_admin!
      require_role!(Roles::ADMIN)
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
