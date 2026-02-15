require "test_helper"

class CategoriesFlowTest < ActionDispatch::IntegrationTest
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

  class FakeCategoriesIndexQuery
    def call(params:)
      {
        items: [],
        scope: "active",
        active: "",
        q: "",
        sort: "name",
        dir: "asc",
        page: 1,
        per_page: 50,
        has_prev: false,
        has_next: false
      }
    end
  end

  class FakeCategoriesCreateUseCase
    def initialize(error: nil)
      @error = error
    end

    def call(form_payload:, actor_id:)
      raise @error if @error

      "cat-1"
    end
  end

  class FakeCategoriesArchiveUseCase
    def initialize(error: nil)
      @error = error
    end

    def call(id:, actor_id:)
      raise @error if @error

      true
    end
  end

  class FakeCategoriesRestoreUseCase
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

  test "viewer cannot access categories index" do
    with_authenticated_context(role: Roles::VIEWER) do
      get categories_path
      assert_redirected_to root_path
    end
  end

  test "operator can access categories index" do
    with_authenticated_context(role: Roles::OPERATOR) do
      with_stubbed_constructor(Categories::IndexQuery, FakeCategoriesIndexQuery.new) do
        get categories_path
        assert_response :success
      end
    end
  end

  test "category create renders validation error on invalid payload" do
    error = ServiceErrors::Validation.new(user_message: "kategori adi bos olamaz")
    fake_use_case = FakeCategoriesCreateUseCase.new(error: error)

    with_authenticated_context(role: Roles::OPERATOR) do
      with_stubbed_constructor(Catalog::UseCases::Categories::Create, fake_use_case) do
        post categories_path, params: { category: { code: "", name: "", active: "1" } }
        assert_response :unprocessable_entity
      end
    end
  end

  test "operator can archive and restore category" do
    with_authenticated_context(role: Roles::OPERATOR) do
      with_stubbed_constructor(Catalog::UseCases::Categories::Archive, FakeCategoriesArchiveUseCase.new) do
        delete category_path("cat-1")
        assert_redirected_to categories_path
      end

      with_stubbed_constructor(Catalog::UseCases::Categories::Restore, FakeCategoriesRestoreUseCase.new) do
        patch restore_category_path("cat-1")
        assert_redirected_to categories_path(scope: "archived")
      end
    end
  end
end

