require "test_helper"

module Auth
  class SessionRefreshTest < ActiveSupport::TestCase
    class FakeAuthClient
      def initialize(response: nil, error: nil)
        @response = response
        @error = error
      end

      def refresh(_refresh_token)
        raise @error if @error

        @response
      end
    end

    test "skips refresh when token is not near expiry" do
      now = 1_700_000_000
      session = { refresh_token: "rt-1", expires_at: now + 600, access_token: "old" }
      service = Auth::SessionRefresh.new(
        auth_client: FakeAuthClient.new(response: { "access_token" => "new" }),
        now: -> { now }
      )

      result = service.call(session: session)

      assert_equal true, result
      assert_equal "old", session[:access_token]
    end

    test "refreshes and rotates tokens near expiry" do
      now = 1_700_000_000
      session = { refresh_token: "rt-old", expires_at: now + 30, access_token: "old" }
      service = Auth::SessionRefresh.new(
        auth_client: FakeAuthClient.new(
          response: {
            "access_token" => "new-access",
            "refresh_token" => "rt-new",
            "expires_in" => 3600
          }
        ),
        now: -> { now }
      )

      result = service.call(session: session)

      assert_equal true, result
      assert_equal "new-access", session[:access_token]
      assert_equal "rt-new", session[:refresh_token]
      assert_equal now + 3600, session[:expires_at]
    end

    test "returns true when refresh response has no access token in non-force mode" do
      now = 1_700_000_000
      session = { refresh_token: "rt-1", expires_at: now + 10, access_token: "old" }
      service = Auth::SessionRefresh.new(
        auth_client: FakeAuthClient.new(response: { "refresh_token" => "rt-2", "expires_in" => 3600 }),
        now: -> { now }
      )

      result = service.call(session: session)

      assert_equal true, result
      assert_equal "old", session[:access_token]
    end

    test "returns true when auth client raises error in non-force mode" do
      now = 1_700_000_000
      session = { refresh_token: "rt-1", expires_at: now + 10, access_token: "old" }
      service = Auth::SessionRefresh.new(
        auth_client: FakeAuthClient.new(error: Supabase::Auth::AuthError.new("invalid refresh")),
        now: -> { now }
      )

      result = service.call(session: session)

      assert_equal true, result
    end

    test "force refresh returns false when refresh token missing" do
      now = 1_700_000_000
      session = { access_token: "old" }
      service = Auth::SessionRefresh.new(
        auth_client: FakeAuthClient.new(response: { "access_token" => "new" }),
        now: -> { now }
      )

      result = service.call(session: session, force: true)

      assert_equal false, result
      assert_equal "old", session[:access_token]
    end

    test "force refresh returns false when auth client raises error" do
      now = 1_700_000_000
      session = { refresh_token: "rt-1", expires_at: now + 10, access_token: "old" }
      service = Auth::SessionRefresh.new(
        auth_client: FakeAuthClient.new(error: Supabase::Auth::AuthError.new("invalid refresh")),
        now: -> { now }
      )

      result = service.call(session: session, force: true)

      assert_equal false, result
      assert_equal "old", session[:access_token]
    end

    test "keeps previous refresh token when response omits new refresh token" do
      now = 1_700_000_000
      session = { refresh_token: "rt-old", expires_at: now + 30, access_token: "old" }
      service = Auth::SessionRefresh.new(
        auth_client: FakeAuthClient.new(
          response: {
            "access_token" => "new-access",
            "expires_in" => 3600
          }
        ),
        now: -> { now }
      )

      result = service.call(session: session)

      assert_equal true, result
      assert_equal "new-access", session[:access_token]
      assert_equal "rt-old", session[:refresh_token]
    end
  end
end
