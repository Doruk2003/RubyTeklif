module Admin
  class UsersController < ApplicationController
    before_action :authorize_admin!

    def index
      result = Admin::Users::IndexQuery.new(client: client).call(params: params)
      @users = result[:items]
      @page = result[:page]
      @per_page = result[:per_page]
      @has_prev = result[:has_prev]
      @has_next = result[:has_next]
    rescue Supabase::Client::ConfigurationError
      @users = []
      @page = 1
      @per_page = 100
      @has_next = false
      @has_prev = false
    end

    def new
      @user = { "role" => Roles::ADMIN }
    end

    def create
      user_params = params.require(:user).permit(:email, :password, :role).to_h
      Admin::Users::Create.new(client: client).call(form_payload: user_params, actor_id: current_user.id)
      redirect_to admin_users_path, notice: "Kullanici olusturuldu."
    rescue ServiceErrors::Base => e
      report_handled_error(e, source: "admin/users#create")
      flash.now[:alert] = "Kullanici olusturulamadi: #{e.user_message}"
      @user = { "email" => user_params&.[]("email").to_s, "role" => user_params&.[]("role").to_s.presence || Roles::ADMIN }
      render :new, status: :unprocessable_entity
    end

    def edit
      data = client.get("users?id=eq.#{Supabase::FilterValue.eq(params[:id])}&select=id,email,role&limit=1")
      @user = data.is_a?(Array) ? data.first : nil
      redirect_to admin_users_path, alert: "Kullanici bulunamadi." if @user.nil?
    rescue Supabase::Client::ConfigurationError
      redirect_to admin_users_path, alert: "Kullanici yuklenemedi."
    end

    def update
      role = params.require(:user).permit(:role)[:role].to_s
      Admin::Users::UpdateRole.new(client: client).call(id: params[:id], role: role, actor_id: current_user.id)
      redirect_to admin_users_path, notice: "Kullanici rolu guncellendi."
    rescue ServiceErrors::Base => e
      report_handled_error(e, source: "admin/users#update")
      redirect_to admin_users_path, alert: "Kullanici guncellenemedi: #{e.user_message}"
    end

    def disable
      Admin::Users::SetActive.new(client: client).call(id: params[:id], active: false, actor_id: current_user.id)
      redirect_to admin_users_path, notice: "Kullanici devre disi birakildi."
    rescue ServiceErrors::Base => e
      report_handled_error(e, source: "admin/users#disable")
      redirect_to admin_users_path, alert: "Kullanici guncellenemedi: #{e.user_message}"
    end

    def enable
      Admin::Users::SetActive.new(client: client).call(id: params[:id], active: true, actor_id: current_user.id)
      redirect_to admin_users_path, notice: "Kullanici aktif edildi."
    rescue ServiceErrors::Base => e
      report_handled_error(e, source: "admin/users#enable")
      redirect_to admin_users_path, alert: "Kullanici guncellenemedi: #{e.user_message}"
    end

    def reset_password
      Admin::Users::ResetPassword.new(client: client).call(id: params[:id])
      redirect_to admin_users_path, notice: "Parola sifirlama maili gonderildi."
    rescue ServiceErrors::Base => e
      report_handled_error(e, source: "admin/users#reset_password")
      redirect_to admin_users_path, alert: "Parola sifirlama gonderilemedi: #{e.user_message}"
    end

    private

    def client
      @client ||= Supabase::Client.new(role: :service)
    end

    def authorize_admin!
      authorize_with_policy!(AdminUsersPolicy)
    end

  end
end
