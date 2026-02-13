require "test_helper"

class AuthRoleCrudFlowTest < ActionDispatch::IntegrationTest
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

  class FakeCompaniesIndexQuery
    def call(params:)
      {
        items: [],
        page: 1,
        per_page: 50,
        has_prev: false,
        has_next: false
      }
    end
  end

  class FakeCompaniesCreateUseCase
    def initialize(error: nil)
      @error = error
    end

    def call(form_payload:, actor_id:)
      raise @error if @error

      { id: "cmp-1", notice: "ok" }
    end
  end

  class FakeCompaniesRestoreUseCase
    def initialize(error: nil)
      @error = error
    end

    def call(id:, actor_id:)
      raise @error if @error

      true
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

  test "viewer cannot access companies index" do
    with_authenticated_context(role: Roles::VIEWER) do
      get companies_path
      assert_redirected_to root_path
    end
  end

  test "operator can access companies index" do
    with_authenticated_context(role: Roles::OPERATOR) do
      with_stubbed_constructor(Companies::IndexQuery, FakeCompaniesIndexQuery.new) do
        get companies_path
        assert_response :success
      end
    end
  end

  test "company create renders validation error on invalid payload" do
    error = ServiceErrors::Validation.new(user_message: "name bos olamaz")
    fake_use_case = FakeCompaniesCreateUseCase.new(error: error)

    with_authenticated_context(role: Roles::OPERATOR) do
      with_stubbed_constructor(Companies::CreateCompany, fake_use_case) do
        post companies_path, params: { company: { name: "", tax_number: "12345678", active: "1" } }
        assert_response :unprocessable_entity
      end
    end
  end

  test "operator can restore archived company" do
    with_authenticated_context(role: Roles::OPERATOR) do
      with_stubbed_constructor(Companies::RestoreCompany, FakeCompaniesRestoreUseCase.new) do
        patch restore_company_path("cmp-1")
        assert_redirected_to companies_path(scope: "archived")
      end
    end
  end
end
