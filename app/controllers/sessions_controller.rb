class SessionsController < ApplicationController
  skip_before_action :authenticate_user!

  def new
  end

  def create
    response = Supabase::Auth.new.sign_in(email: params[:email].to_s, password: params[:password].to_s)
    reset_session
    session[:access_token] = response["access_token"]
    session[:refresh_token] = response["refresh_token"]
    session[:expires_at] = Time.now.to_i + response["expires_in"].to_i if response["expires_in"].present?
    redirect_to root_path
  rescue Supabase::Auth::AuthError => e
    flash.now[:alert] = "Giris yapilamadi: #{e.message}"
    render :new, status: :unprocessable_entity
  end

  def destroy
    Supabase::Auth.new.sign_out(session[:access_token].to_s) if session[:access_token].present?
    reset_session
    redirect_to login_path
  end
end
