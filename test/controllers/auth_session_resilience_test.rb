require "test_helper"

class AuthSessionResilienceTest < ActionDispatch::IntegrationTest
  class FakeAuth
    def initialize(user_id:)
      @user_id = user_id
    end

    def sign_in(email:, password:)
      {
        "access_token" => "token-#{@user_id}",
        "refresh_token" => "refresh-#{@user_id}",
        "expires_in" => 3600
      }
    end

    def user(access_token)
      return { "id" => @user_id, "email" => "user@example.com" } if access_token.to_s.start_with?("token-")

      nil
    end
  end

  class FakeAuthInvalidUser < FakeAuth
    def user(access_token)
      nil
    end
  end

  class FakeSessionRefreshFail
    def call(session:, force: false)
      false
    end
  end

  class FakeUsersRepository
    def initialize(user_id:, role:)
      @user_id = user_id
      @role = role
    end

    def find_by_id(id)
      return nil unless id.to_s == @user_id

      { "id" => @user_id, "email" => "user@example.com", "role" => @role, "active" => true }
    end
  end

  class FakeCompaniesIndexQuery
    def call(params:, **_kwargs)
      {
        items: [],
        page: 1,
        per_page: 50,
        has_prev: false,
        has_next: false
      }
    end
  end

  private def with_stubbed_constructor(klass, instance)
    original_new = klass.method(:new)
    klass.singleton_class.send(:define_method, :new) do |*args, **kwargs, &blk|
      instance
    end
    yield
  ensure
    klass.singleton_class.send(:define_method, :new) do |*args, **kwargs, &blk|
      original_new.call(*args, **kwargs, &blk)
    end
  end

  private def with_authenticated_context(role:, user_id: "usr-1")
    fake_auth = FakeAuth.new(user_id: user_id)
    fake_repo = FakeUsersRepository.new(user_id: user_id, role: role)

    with_stubbed_constructor(Supabase::Auth, fake_auth) do
      with_stubbed_constructor(Users::Repository, fake_repo) do
        post login_path, params: { email: "user@example.com", password: "Password12" }
        assert_redirected_to root_path
        follow_redirect!
        yield
      end
    end
  end

  test "refresh failure falls back to existing valid access token" do
    with_authenticated_context(role: Roles::OPERATOR) do
      with_stubbed_constructor(Auth::SessionRefresh, FakeSessionRefreshFail.new) do
        with_stubbed_constructor(Companies::IndexQuery, FakeCompaniesIndexQuery.new) do
          get companies_path
          assert_response :success
        end
      end
    end
  end

  test "refresh failure with invalid token resets session and redirects to login" do
    with_authenticated_context(role: Roles::OPERATOR) do
      with_stubbed_constructor(Supabase::Auth, FakeAuthInvalidUser.new(user_id: "usr-1")) do
        with_stubbed_constructor(Auth::SessionRefresh, FakeSessionRefreshFail.new) do
          get companies_path
          assert_redirected_to login_path
          assert_equal Auth::Messages::SESSION_REFRESH_FAILED, flash[:alert]
        end
      end
    end
  end
end

