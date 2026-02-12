module Admin
  class UsersController < ApplicationController
    before_action :authorize_admin!

    def index
      query = build_query
      data = client.get(query)
      @users = data.is_a?(Array) ? data : []
    rescue Supabase::Client::ConfigurationError
      @users = []
    end

    def new
      @user = { "role" => Roles::ADMIN }
    end

    def create
      user_params = params.require(:user).permit(:email, :password, :role)
      email = user_params[:email].to_s
      password = user_params[:password].to_s
      role = user_params[:role].to_s.presence || Roles::ADMIN

      created = Supabase::Auth.new.create_user(email: email, password: password, role: role)
      user_id = created.is_a?(Hash) ? (created["id"].presence || created.dig("user", "id").to_s) : nil
      raise "Kullanici olusturulamadi." if user_id.blank?

      # Ensure role row exists in public.users
      client.post("users", body: { id: user_id, email: email, role: role, active: true }, headers: { "Prefer" => "return=minimal" })
      redirect_to admin_users_path, notice: "Kullanici olusturuldu."
    rescue Supabase::Auth::AuthError => e
      message = e.message.to_s
      if message.downcase.include?("already") || message.downcase.include?("registered")
        flash.now[:alert] = "Bu e-posta zaten kayitli."
      else
        flash.now[:alert] = "Kullanici olusturulamadi: #{message}"
      end
      @user = { "email" => email, "role" => role }
      return render :new, status: :unprocessable_entity
    rescue StandardError => e
      flash.now[:alert] = "Kullanici olusturulamadi: #{e.message}"
      @user = { "email" => email, "role" => role }
      return render :new, status: :unprocessable_entity
    end

    def edit
      data = client.get("users?id=eq.#{params[:id]}&select=id,email,role&limit=1")
      @user = data.is_a?(Array) ? data.first : nil
      redirect_to admin_users_path, alert: "Kullanici bulunamadi." if @user.nil?
    rescue Supabase::Client::ConfigurationError
      redirect_to admin_users_path, alert: "Kullanici yuklenemedi."
    end

    def update
      payload = { role: params[:user].to_h[:role].to_s }
      payload[:role] = Roles::ADMIN if payload[:role].blank?

      client.patch("users?id=eq.#{params[:id]}", body: payload, headers: { "Prefer" => "return=representation" })
      log_role_change(payload[:role])
      redirect_to admin_users_path, notice: "Kullanici rolu guncellendi."
    rescue StandardError => e
      redirect_to admin_users_path, alert: "Kullanici guncellenemedi: #{e.message}"
    end

    def disable
      client.patch("users?id=eq.#{params[:id]}", body: { active: false }, headers: { "Prefer" => "return=representation" })
      redirect_to admin_users_path, notice: "Kullanici devre disi birakildi."
    rescue StandardError => e
      redirect_to admin_users_path, alert: "Kullanici guncellenemedi: #{e.message}"
    end

    def enable
      client.patch("users?id=eq.#{params[:id]}", body: { active: true }, headers: { "Prefer" => "return=representation" })
      redirect_to admin_users_path, notice: "Kullanici aktif edildi."
    rescue StandardError => e
      redirect_to admin_users_path, alert: "Kullanici guncellenemedi: #{e.message}"
    end

    def reset_password
      data = client.get("users?id=eq.#{params[:id]}&select=email&limit=1")
      user = data.is_a?(Array) ? data.first : nil
      email = user.is_a?(Hash) ? user["email"].to_s : ""
      raise "E-posta bulunamadi." if email.blank?

      Supabase::Auth.new.send_recovery(email: email)
      redirect_to admin_users_path, notice: "Parola sifirlama maili gonderildi."
    rescue StandardError => e
      redirect_to admin_users_path, alert: "Parola sifirlama gonderilemedi: #{e.message}"
    end

    private

    def client
      @client ||= Supabase::Client.new(role: :service)
    end

    def authorize_admin!
      require_role!(Roles::ADMIN)
    end

    def build_query
      base = "users?select=id,email,role,active&order=email.asc"
      filters = []
      if params[:q].present?
        q = params[:q].to_s.strip
        filters << "email=ilike.*#{q}*"
      end
      if params[:role].present?
        filters << "role=eq.#{params[:role]}"
      end
      if params[:active].present?
        filters << "active=eq.#{params[:active]}"
      end
      filters.empty? ? base : "#{base}&#{filters.join('&')}"
    end

    def log_role_change(role)
      return if current_user.nil?

      payload = {
        action: "role_change",
        actor_id: current_user.id,
        target_id: params[:id],
        metadata: { role: role }.to_json,
        created_at: Time.now.utc.iso8601
      }
      client.post("activity_logs", body: payload, headers: { "Prefer" => "return=minimal" })
    rescue StandardError
      nil
    end
  end
end
