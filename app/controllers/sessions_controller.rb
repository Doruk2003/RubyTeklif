class SessionsController < ApplicationController
  skip_before_action :authenticate_user!
  REMEMBER_ME_EXPIRE_AFTER = 30.days

  def new
  end

  def recovery
  end

  def create
    remember_me = ActiveModel::Type::Boolean.new.cast(params[:remember_me])
    response = Supabase::Auth.new.sign_in(email: params[:email].to_s, password: params[:password].to_s)
    reset_session
    request.session_options[:expire_after] = REMEMBER_ME_EXPIRE_AFTER if remember_me
    session[:access_token] = response["access_token"]
    session[:refresh_token] = response["refresh_token"]
    session[:expires_at] = Time.now.to_i + response["expires_in"].to_i if response["expires_in"].present?
    session[:remember_me] = remember_me
    session[:last_seen_at] = Time.now.to_i
    redirect_to root_path
  rescue Supabase::Auth::AuthError => e
    flash.now[:alert] = "#{Auth::Messages::LOGIN_FAILED_PREFIX}: #{e.message}"
    render :new, status: :unprocessable_entity
  end

  def send_recovery
    email = params[:email].to_s.strip
    if email.blank?
      flash.now[:alert] = Auth::Messages::RECOVERY_EMAIL_REQUIRED
      return render :recovery, status: :unprocessable_entity
    end

    Supabase::Auth.new.send_recovery(email: email)
    redirect_to login_path, notice: Auth::Messages::RECOVERY_SENT
  rescue Supabase::Auth::AuthError => e
    flash.now[:alert] = "#{Auth::Messages::RECOVERY_FAILED_PREFIX}: #{e.message}"
    render :recovery, status: :unprocessable_entity
  end

  def destroy
    Supabase::Auth.new.sign_out(session[:access_token].to_s) if session[:access_token].present?
    reset_session
    redirect_to login_path
  end
end
