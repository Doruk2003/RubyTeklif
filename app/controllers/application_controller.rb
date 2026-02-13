class ApplicationController < ActionController::Base
  STANDARD_IDLE_TIMEOUT_SECONDS = 8.hours.to_i
  REMEMBER_ME_IDLE_TIMEOUT_SECONDS = 30.days.to_i

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

  def supabase_user_client
    @supabase_user_client ||= Supabase::Client.new(role: :user, access_token: session[:access_token].to_s)
  end

  def authenticate_user!
    return expire_session!(message: "Oturum süreniz doldu. Lütfen tekrar giriş yapın.") if session_timed_out?

    refresh_session_if_needed
    return expire_session! if @session_refresh_failed

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
          expire_session!
        end
      else
        expire_session!
      end
    end
  end

  def require_role!(*roles)
    authenticate_user! unless current_user
    allowed = roles.map(&:to_s)
    return if current_user && allowed.include?(current_user.role)

    redirect_to root_path, alert: "Bu işlem için yetkiniz yok."
  end

  def load_current_user(auth_user)
    db_user = Users::Repository.new.find_by_id(auth_user["id"])
    if db_user && db_user.key?("active") && db_user["active"] == false
      Current.user = nil
      reset_session
      return redirect_to login_path, alert: "Hesabınız devre dışı."
    end

    role = db_user&.fetch("role", nil).presence || ENV.fetch("APP_DEFAULT_ROLE", Roles::ADMIN)
    Current.user = CurrentUser.new(role: role, id: auth_user["id"], name: auth_user["email"])
  end

  def refresh_session_if_needed
    @session_refresh_failed = !session_refresh.call(session: session)
  end

  def refresh_session
    session_refresh.call(session: session, force: true)
  end

  def expire_session!(message: "Oturumunuz sona erdi. Lütfen tekrar giriş yapın.")
    Current.user = nil
    reset_session
    redirect_to login_path, alert: message
  end

  def session_refresh
    @session_refresh ||= Auth::SessionRefresh.new
  end

  def session_timed_out?
    last_seen_at = session[:last_seen_at].to_i
    return false if last_seen_at.zero?

    now = Time.now.to_i
    timeout = remember_me_enabled? ? REMEMBER_ME_IDLE_TIMEOUT_SECONDS : STANDARD_IDLE_TIMEOUT_SECONDS
    if (now - last_seen_at) > timeout
      true
    else
      session[:last_seen_at] = now
      false
    end
  end

  def remember_me_enabled?
    ActiveModel::Type::Boolean.new.cast(session[:remember_me])
  end
end
