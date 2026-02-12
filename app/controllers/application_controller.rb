class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :authenticate_user!

  helper_method :current_user

  private

  def current_user
    Current.user
  end

  def authenticate_user!
    refresh_session_if_needed
    access_token = session[:access_token].to_s
    if access_token.blank?
      Current.user = nil
      return redirect_to login_path
    end

    auth_user = Supabase::Auth.new.user(access_token)
    if auth_user.is_a?(Hash) && auth_user["id"].present?
      load_current_user(auth_user)
    else
      refreshed = refresh_session
      if refreshed
        auth_user = Supabase::Auth.new.user(session[:access_token].to_s)
        if auth_user.is_a?(Hash) && auth_user["id"].present?
          load_current_user(auth_user)
        else
          Current.user = nil
          redirect_to login_path
        end
      else
        Current.user = nil
        redirect_to login_path
      end
    end
  end

  def require_role!(*roles)
    authenticate_user! unless current_user
    allowed = roles.map(&:to_s)
    return if current_user && allowed.include?(current_user.role)

    redirect_to root_path, alert: "Bu islem icin yetkiniz yok."
  end

  def load_current_user(auth_user)
    db_user = Users::Repository.new.find_by_id(auth_user["id"])
    if db_user && db_user.key?("active") && db_user["active"] == false
      Current.user = nil
      reset_session
      return redirect_to login_path, alert: "Hesabiniz devre disi."
    end

    role = db_user&.fetch("role", nil).presence || ENV.fetch("APP_DEFAULT_ROLE", Roles::ADMIN)
    Current.user = CurrentUser.new(role: role, id: auth_user["id"], name: auth_user["email"])
  end

  def refresh_session_if_needed
    return if session[:refresh_token].blank?

    expires_at = session[:expires_at].to_i
    return if expires_at.zero?

    refresh_session if Time.now.to_i >= (expires_at - 60)
  end

  def refresh_session
    response = Supabase::Auth.new.refresh(session[:refresh_token].to_s)
    access_token = response["access_token"].to_s
    return false if access_token.blank?

    session[:access_token] = access_token
    session[:refresh_token] = response["refresh_token"].to_s if response["refresh_token"].present?
    session[:expires_at] = Time.now.to_i + response["expires_in"].to_i if response["expires_in"].present?
    true
  rescue Supabase::Auth::AuthError
    false
  end
end
