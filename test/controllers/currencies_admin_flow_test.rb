require "test_helper"

class CurrenciesAdminFlowTest < ActionDispatch::IntegrationTest
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
      { "id" => @user_id, "email" => "user@example.com" }
    end
  end

  class FakeSessionRefresh
    def call(session:, force: false)
      true
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

  class FakeCurrenciesIndexQuery
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

  class FakeCurrenciesCreateUseCase
    def initialize(error: nil)
      @error = error
    end

    def call(form_payload:, actor_id:)
      raise @error if @error

      "cur-1"
    end
  end

  class FakeCurrenciesRestoreUseCase
    def initialize(error: nil)
      @error = error
    end

    def call(id:, actor_id:)
      raise @error if @error

      true
    end
  end

  class FakeAdminUsersIndexQuery
    def call(params:, **_kwargs)
      {
        items: [],
        page: 1,
        per_page: 100,
        has_prev: false,
        has_next: false
      }
    end
  end

  class FakeAdminUsersUpdateRole
    def initialize(error: nil)
      @error = error
    end

    def call(id:, role:, actor_id:)
      raise @error if @error

      true
    end
  end

  class FakeAdminUsersSetActive
    def initialize(error: nil)
      @error = error
    end

    def call(id:, active:, actor_id:)
      raise @error if @error

      { action: active ? "users.enable" : "users.disable", target_id: id }
    end
  end

  class FakeResetPasswordJob
    attr_reader :calls

    def initialize
      @calls = []
    end

    def perform_later(target_user_id, actor_id)
      @calls << { target_user_id: target_user_id, actor_id: actor_id }
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
    fake_refresh = FakeSessionRefresh.new
    fake_repo = FakeUsersRepository.new(user_id: user_id, role: role)

    with_stubbed_constructor(Supabase::Auth, fake_auth) do
      with_stubbed_constructor(Auth::SessionRefresh, fake_refresh) do
        with_stubbed_constructor(Users::Repository, fake_repo) do
          post login_path, params: { email: "user@example.com", password: "Password12" }
          assert_redirected_to root_path
          follow_redirect!
          yield
        end
      end
    end
  end

  test "operator cannot access currencies index" do
    with_authenticated_context(role: Roles::OPERATOR) do
      get currencies_path
      assert_redirected_to root_path
    end
  end

  test "manager can access currencies index" do
    with_authenticated_context(role: Roles::MANAGER) do
      with_stubbed_constructor(Currencies::IndexQuery, FakeCurrenciesIndexQuery.new) do
        get currencies_path
        assert_response :success
      end
    end
  end

  test "currency create renders validation error on invalid payload" do
    error = ServiceErrors::Validation.new(user_message: "code bos olamaz")
    fake_use_case = FakeCurrenciesCreateUseCase.new(error: error)

    with_authenticated_context(role: Roles::MANAGER) do
      with_stubbed_constructor(Catalog::UseCases::Currencies::Create, fake_use_case) do
        post currencies_path, params: { currency: { code: "", name: "USD", symbol: "$", rate_to_try: "35", active: "1" } }
        assert_response :unprocessable_entity
      end
    end
  end

  test "manager can restore archived currency" do
    with_authenticated_context(role: Roles::MANAGER) do
      with_stubbed_constructor(Catalog::UseCases::Currencies::Restore, FakeCurrenciesRestoreUseCase.new) do
        patch restore_currency_path("cur-1")
        assert_redirected_to currencies_path(scope: "archived")
      end
    end
  end

  test "manager cannot access admin users index" do
    with_authenticated_context(role: Roles::MANAGER) do
      get admin_users_path
      assert_redirected_to root_path
    end
  end

  test "admin can access admin users index" do
    with_authenticated_context(role: Roles::ADMIN) do
      with_stubbed_constructor(Admin::Users::IndexQuery, FakeAdminUsersIndexQuery.new) do
        get admin_users_path
        assert_response :success
      end
    end
  end

  test "admin user role update returns alert on validation error" do
    error = ServiceErrors::Validation.new(user_message: "Gecersiz rol secimi.")
    fake_update = FakeAdminUsersUpdateRole.new(error: error)

    with_authenticated_context(role: Roles::ADMIN) do
      with_stubbed_constructor(Admin::Users::UseCases::UpdateUserRole, fake_update) do
        patch admin_user_path("usr-2"), params: { user: { role: "invalid" } }
        assert_redirected_to admin_users_path
      end
    end
  end

  test "admin cannot demote last active admin and gets clear alert" do
    error = ServiceErrors::Validation.new(user_message: "Son aktif adminin rolu degistirilemez.")
    fake_update = FakeAdminUsersUpdateRole.new(error: error)

    with_authenticated_context(role: Roles::ADMIN) do
      with_stubbed_constructor(Admin::Users::UseCases::UpdateUserRole, fake_update) do
        patch admin_user_path("usr-1"), params: { user: { role: Roles::MANAGER } }
        assert_redirected_to admin_users_path
        assert_includes flash[:alert], "Son aktif adminin rolu degistirilemez."
      end
    end
  end

  test "admin cannot disable last active admin and gets clear alert" do
    error = ServiceErrors::Validation.new(user_message: "Son aktif admin kullanicisi devre disi birakilamaz.")
    fake_set_active = FakeAdminUsersSetActive.new(error: error)

    with_authenticated_context(role: Roles::ADMIN) do
      with_stubbed_constructor(Admin::Users::UseCases::SetUserActive, fake_set_active) do
        patch disable_admin_user_path("usr-1")
        assert_redirected_to admin_users_path
        assert_includes flash[:alert], "Son aktif admin kullanicisi devre disi birakilamaz."
      end
    end
  end

  test "admin cannot disable self and gets clear alert" do
    error = ServiceErrors::Validation.new(user_message: "Kendi kullanicinizi devre disi birakamazsiniz.")
    fake_set_active = FakeAdminUsersSetActive.new(error: error)

    with_authenticated_context(role: Roles::ADMIN) do
      with_stubbed_constructor(Admin::Users::UseCases::SetUserActive, fake_set_active) do
        patch disable_admin_user_path("usr-1")
        assert_redirected_to admin_users_path
        assert_includes flash[:alert], "Kendi kullanicinizi devre disi birakamazsiniz."
      end
    end
  end

  test "admin reset password enqueues background job" do
    fake_job = FakeResetPasswordJob.new
    with_authenticated_context(role: Roles::ADMIN) do
      original_perform_later = Admin::Users::ResetPasswordJob.method(:perform_later)
      Admin::Users::ResetPasswordJob.singleton_class.send(:define_method, :perform_later) do |target_user_id, actor_id|
        fake_job.perform_later(target_user_id, actor_id)
      end

      post reset_password_admin_user_path("usr-2")
      assert_equal [{ target_user_id: "usr-2", actor_id: "usr-1" }], fake_job.calls
      assert_redirected_to admin_users_path
    ensure
      Admin::Users::ResetPasswordJob.singleton_class.send(:define_method, :perform_later) do |target_user_id, actor_id|
        original_perform_later.call(target_user_id, actor_id)
      end
    end
  end
end


