class ApplicationController < ActionController::Base
  STANDARD_IDLE_TIMEOUT_SECONDS = 8.hours.to_i
  REMEMBER_ME_IDLE_TIMEOUT_SECONDS = 30.days.to_i

  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :authenticate_user!
  rescue_from StandardError, with: :handle_unexpected_error

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

    refresh_failed = !refresh_session_if_needed

    access_token = session[:access_token].to_s
    if access_token.blank?
      Current.user = nil
      return expire_session!(message: expired_message(refresh_failed: refresh_failed))
    end

    auth_user = Supabase::Auth.new.user(access_token)
    if auth_user.is_a?(Hash) && auth_user["id"].present?
      load_current_user(auth_user)
      return
    end

    refreshed = refresh_session
    if refreshed
      auth_user = Supabase::Auth.new.user(session[:access_token].to_s)
      if auth_user.is_a?(Hash) && auth_user["id"].present?
        load_current_user(auth_user)
        return
      end
    end

    expire_session!(message: expired_message(refresh_failed: refresh_failed))
  end

  def require_role!(*roles)
    authenticate_user! unless current_user
    allowed = roles.map(&:to_s)
    return if current_user && allowed.include?(current_user.role)

    redirect_to root_path, alert: "Bu işlem için yetkiniz yok."
  end

  def authorize_with_policy!(policy_class, query: :access?)
    authenticate_user! unless current_user
    policy = policy_class.new(current_user)
    return if policy.public_send(query)

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
    session_refresh.call(session: session)
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

  def expired_message(refresh_failed:)
    return "Oturum yenilenemedi. Lütfen tekrar giriş yapın." if refresh_failed

    "Oturumunuz sona erdi. Lütfen tekrar giriş yapın."
  end

  def report_handled_error(error, source:)
    Observability::ErrorReporter.report(
      error,
      severity: :warn,
      context: error_context.merge(source: source)
    )
  end

  def handle_unexpected_error(error)
    report_handled_error(error, source: "unhandled_exception")
    raise error if Rails.env.development? || Rails.env.test?

    redirect_to root_path, alert: "Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin."
  end

  def error_context
    {
      request_id: request&.request_id,
      path: request&.fullpath,
      method: request&.request_method,
      user_id: current_user&.id
    }
  end
end
