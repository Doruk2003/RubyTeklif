module Admin
  class ActivityLogsController < ApplicationController
    before_action :authorize_admin!
    EXPORT_TTL = 30.minutes

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
      @export = current_export_state
    rescue Supabase::Client::ConfigurationError
      @logs = []
      @users_index = {}
      @action_options = []
      @target_type_options = []
      @page = 1
      @per_page = 100
      @has_next = false
      @has_prev = false
      @export = nil
    rescue ServiceErrors::System => e
      report_handled_error(e, source: "admin/activity_logs#index", severity: :error)
      @logs = []
      @users_index = {}
      @action_options = []
      @target_type_options = []
      @page = 1
      @per_page = 100
      @has_next = false
      @has_prev = false
      @export = nil
      flash.now[:alert] = e.user_message
    end

    def export
      token = SecureRandom.hex(12)
      Rails.cache.write(
        export_cache_key(token),
        { status: "pending", actor_id: current_user.id },
        expires_in: EXPORT_TTL
      )
      session[:activity_logs_export_token] = token

      Admin::ActivityLogs::ExportCsvJob.perform_later(token, current_user.id, export_params.to_h)
      redirect_to admin_activity_logs_path(export_params.to_h), notice: "CSV export kuyruga alindi."
    end

    def download_export
      state = current_export_state
      unless state.is_a?(Hash) && state[:actor_id].to_s == current_user.id.to_s
        return redirect_to admin_activity_logs_path, alert: "Export kaydi bulunamadi."
      end

      if state[:status].to_s != "ready"
        return redirect_to admin_activity_logs_path, alert: "Export henuz hazir degil."
      end

      file_path = state[:file_path].to_s
      unless file_path.present? && File.exist?(file_path)
        return redirect_to admin_activity_logs_path, alert: "Export dosyasi bulunamadi."
      end

      send_data File.binread(file_path), filename: "activity_logs_#{Date.current.iso8601}.csv", type: "text/csv"
    end

    private

    def client
      @client ||= Supabase::Client.new(role: :service)
    end

    def authorize_admin!
      authorize_with_policy!(AdminActivityLogsPolicy)
    end

    def load_users_index
      Admin::Users::EmailIndexQuery.new(client: client).call
    end

    def export_params
      Admin::ActivityLogs::ExportForm.new(
        event_action: params[:event_action],
        actor: params[:actor],
        target: params[:target],
        target_type: params[:target_type],
        from: params[:from],
        to: params[:to]
      ).to_h
    end

    def current_export_state
      token = session[:activity_logs_export_token].to_s
      return nil if token.blank?

      state = normalized_export_state(Rails.cache.read(export_cache_key(token)))
      return nil unless state.is_a?(Hash)
      return nil unless state[:actor_id].to_s == current_user.id.to_s

      state.merge(token: token)
    end

    def export_cache_key(token)
      "admin/activity_logs/export/#{token}"
    end

    def normalized_export_state(state)
      return nil unless state.is_a?(Hash)

      state.to_h.symbolize_keys
    end
  end
end
