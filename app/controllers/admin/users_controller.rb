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
    rescue ServiceErrors::System => e
      report_handled_error(e, source: "admin/users#index", severity: :error)
      @users = []
      @page = 1
      @per_page = 100
      @has_next = false
      @has_prev = false
      @export = nil
      flash.now[:alert] = e.user_message
    end

    def new
      @user = { "role" => Roles::ADMIN }
    end

    def create
      form = Admin::Users::CreateForm.new(params.require(:user).permit(:email, :password, :role).to_h)
      return render_create_error(form: form, message: form.errors.full_messages.join(", ")) if form.invalid?

      Admin::Users::UseCases::CreateUser.new(client: client).call(form_payload: form.to_h, actor_id: current_user.id)
      redirect_to admin_users_path, notice: "Kullanici olusturuldu."
    rescue ServiceErrors::Base => e
      report_handled_error(e, source: "admin/users#create")
      render_create_error(form: form, message: e.user_message)
    end

    def edit
      @user = Admin::Users::ShowQuery.new(client: client).call(id: params[:id])
      redirect_to admin_users_path, alert: "Kullanici bulunamadi." if @user.nil?
    rescue Supabase::Client::ConfigurationError
      redirect_to admin_users_path, alert: "Kullanici yuklenemedi."
    rescue ServiceErrors::System => e
      report_handled_error(e, source: "admin/users#edit", severity: :error)
      redirect_to admin_users_path, alert: e.user_message
    end

    def update
      form = Admin::Users::UpdateRoleForm.new(params.require(:user).permit(:role).to_h)
      if form.invalid?
        return redirect_to admin_users_path, alert: "Kullanici guncellenemedi: #{form.errors.full_messages.join(', ')}"
      end

      Admin::Users::UseCases::UpdateUserRole.new(client: client).call(id: params[:id], role: form.role, actor_id: current_user.id)
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

      Admin::Users::ExportCsvJob.perform_later(token, current_user.id, export_params)
      redirect_to admin_users_path(export_params), notice: "CSV export kuyruğa alındı."
    end

    def download_export
      state = current_export_state
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

      send_data File.binread(file_path), filename: "admin_users_#{Date.current.iso8601}.csv", type: "text/csv"
    end

    private

    def client
      @client ||= Supabase::Client.new(role: :service)
    end

    def authorize_admin!
      authorize_with_policy!(AdminUsersPolicy)
    end

    def export_params
      form = Admin::Users::ExportForm.new(
        q: params[:q],
        role: params[:role],
        active: params[:active]
      )
      return form.to_h if form.valid?

      { q: params[:q].to_s.presence }.compact
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

    def render_create_error(form:, message:)
      flash.now[:alert] = "Kullanici olusturulamadi: #{message}"
      @user = { "email" => form&.email.to_s, "role" => form&.role.to_s.presence || Roles::ADMIN }
      render :new, status: :unprocessable_entity
    end
  end
end
