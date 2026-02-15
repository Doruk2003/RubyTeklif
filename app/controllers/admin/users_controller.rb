module Admin
  class UsersController < ApplicationController
    before_action :authorize_admin!
    EXPORT_TTL = 30.minutes

    def index
      result = Admin::Users::IndexQuery.new(client: client).call(params: params)
      @users = result[:items]
      @page = result[:page]
      @per_page = result[:per_page]
      @has_prev = result[:has_prev]
      @has_next = result[:has_next]
      @export = current_export_state
    rescue Supabase::Client::ConfigurationError
      @users = []
      @page = 1
      @per_page = 100
      @has_next = false
      @has_prev = false
      @export = nil
    end

    def new
      @user = { "role" => Roles::ADMIN }
    end

    def create
      user_params = params.require(:user).permit(:email, :password, :role).to_h
      Admin::Users::UseCases::CreateUser.new(client: client).call(form_payload: user_params, actor_id: current_user.id)
      redirect_to admin_users_path, notice: "Kullanici olusturuldu."
    rescue ServiceErrors::Base => e
      report_handled_error(e, source: "admin/users#create")
      flash.now[:alert] = "Kullanici olusturulamadi: #{e.user_message}"
      @user = { "email" => user_params&.[]("email").to_s, "role" => user_params&.[]("role").to_s.presence || Roles::ADMIN }
      render :new, status: :unprocessable_entity
    end

    def edit
      @user = Admin::Users::ShowQuery.new(client: client).call(id: params[:id])
      redirect_to admin_users_path, alert: "Kullanici bulunamadi." if @user.nil?
    rescue Supabase::Client::ConfigurationError
      redirect_to admin_users_path, alert: "Kullanici yuklenemedi."
    end

    def update
      role = params.require(:user).permit(:role)[:role].to_s
      Admin::Users::UseCases::UpdateUserRole.new(client: client).call(id: params[:id], role: role, actor_id: current_user.id)
      redirect_to admin_users_path, notice: "Kullanici rolu guncellendi."
    rescue ServiceErrors::Base => e
      report_handled_error(e, source: "admin/users#update")
      redirect_to admin_users_path, alert: "Kullanici guncellenemedi: #{e.user_message}"
    end

    def disable
      Admin::Users::UseCases::SetUserActive.new(client: client).call(id: params[:id], active: false, actor_id: current_user.id)
      redirect_to admin_users_path, notice: "Kullanici devre disi birakildi."
    rescue ServiceErrors::Base => e
      report_handled_error(e, source: "admin/users#disable")
      redirect_to admin_users_path, alert: "Kullanici guncellenemedi: #{e.user_message}"
    end

    def enable
      Admin::Users::UseCases::SetUserActive.new(client: client).call(id: params[:id], active: true, actor_id: current_user.id)
      redirect_to admin_users_path, notice: "Kullanici aktif edildi."
    rescue ServiceErrors::Base => e
      report_handled_error(e, source: "admin/users#enable")
      redirect_to admin_users_path, alert: "Kullanici guncellenemedi: #{e.user_message}"
    end

    def reset_password
      Admin::Users::ResetPasswordJob.perform_later(params[:id], current_user.id)
      redirect_to admin_users_path, notice: "Parola sifirlama talebi kuyruga alindi."
    rescue StandardError => e
      report_handled_error(e, source: "admin/users#reset_password")
      redirect_to admin_users_path, alert: "Parola sifirlama baslatilamadi."
    end

    def export
      token = SecureRandom.hex(12)
      Rails.cache.write(
        export_cache_key(token),
        { status: "pending", actor_id: current_user.id },
        expires_in: EXPORT_TTL
      )
      session[:admin_users_export_token] = token

      Admin::Users::ExportCsvJob.perform_later(token, current_user.id, export_params.to_h)
      redirect_to admin_users_path(export_params.to_h), notice: "CSV export kuyruğa alındı."
    end

    def download_export
      state = normalized_export_state(Rails.cache.read(export_cache_key(params[:token].to_s)))
      unless state.is_a?(Hash) && state[:actor_id].to_s == current_user.id.to_s
        return redirect_to admin_users_path, alert: "Export kaydı bulunamadı."
      end

      if state[:status].to_s != "ready"
        return redirect_to admin_users_path, alert: "Export henüz hazır değil."
      end

      file_path = state[:file_path].to_s
      unless file_path.present? && File.exist?(file_path)
        return redirect_to admin_users_path, alert: "Export dosyası bulunamadı."
      end

      send_file file_path, filename: "admin_users_#{Date.current.iso8601}.csv", type: "text/csv"
    end

    private

    def client
      @client ||= Supabase::Client.new(role: :service)
    end

    def authorize_admin!
      authorize_with_policy!(AdminUsersPolicy)
    end

    def export_params
      params.permit(:q, :role, :active)
    end

    def current_export_state
      token = session[:admin_users_export_token].to_s
      return nil if token.blank?

      state = normalized_export_state(Rails.cache.read(export_cache_key(token)))
      return nil unless state.is_a?(Hash)
      return nil unless state[:actor_id].to_s == current_user.id.to_s

      state.merge(token: token)
    end

    def export_cache_key(token)
      "admin/users/export/#{token}"
    end

    def normalized_export_state(state)
      return nil unless state.is_a?(Hash)

      state.to_h.symbolize_keys
    end
  end
end
