module Auth
  class SessionRefresh
    REFRESH_THRESHOLD_SECONDS = 60

    def initialize(auth_client: Supabase::Auth.new, now: -> { Time.now.to_i })
      @auth_client = auth_client
      @now = now
    end

    def call(session:, force: false)
      refresh_token = session[:refresh_token].to_s
      return !force if refresh_token.blank?
      return true unless should_refresh?(session, force: force)

      response = @auth_client.refresh(refresh_token)
      access_token = response["access_token"].to_s
      return false if access_token.blank?

      session[:access_token] = access_token
      session[:refresh_token] = response["refresh_token"].to_s if response["refresh_token"].present?
      session[:expires_at] = @now.call + response["expires_in"].to_i if response["expires_in"].present?
      true
    rescue Supabase::Auth::AuthError
      false
    end

    private

    def should_refresh?(session, force:)
      return true if force

      expires_at = session[:expires_at].to_i
      return false if expires_at.zero?

      @now.call >= (expires_at - REFRESH_THRESHOLD_SECONDS)
    end
  end
end

