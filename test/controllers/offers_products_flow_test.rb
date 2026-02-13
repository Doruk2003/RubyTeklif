require "test_helper"

class OffersProductsFlowTest < ActionDispatch::IntegrationTest
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

  class FakeProductsIndexQuery
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

  class FakeOffersIndexQuery
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

  class FakeProductsCreateUseCase
    def initialize(error: nil)
      @error = error
    end

    def call(form_payload:, actor_id:)
      raise @error if @error

      "prd-1"
    end
  end

  class FakeProductsUpdateUseCase
    def initialize(error: nil)
      @error = error
    end

    def call(id:, form_payload:, actor_id:)
      raise @error if @error

      { id: id, payload: form_payload }
    end
  end

  class FakeOffersCreateUseCase
    def initialize(error: nil)
      @error = error
    end

    def call(payload:, user_id:)
      raise @error if @error

      "off-1"
    end
  end

  class FakeCategoriesOptionsQuery
    def call(active_only: false)
      []
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

  test "viewer cannot access products index" do
    with_authenticated_context(role: Roles::VIEWER) do
      get products_path
      assert_redirected_to root_path
    end
  end

  test "operator can access products index" do
    with_authenticated_context(role: Roles::OPERATOR) do
      with_stubbed_constructor(Products::IndexQuery, FakeProductsIndexQuery.new) do
        with_stubbed_constructor(Categories::OptionsQuery, FakeCategoriesOptionsQuery.new) do
          get products_path
          assert_response :success
        end
      end
    end
  end

  test "products create renders validation error on invalid payload" do
    error = ServiceErrors::Validation.new(user_message: "urun adi bos olamaz")
    fake_use_case = FakeProductsCreateUseCase.new(error: error)

    with_authenticated_context(role: Roles::OPERATOR) do
      with_stubbed_constructor(Products::CreateProduct, fake_use_case) do
        with_stubbed_constructor(Categories::OptionsQuery, FakeCategoriesOptionsQuery.new) do
          post products_path, params: { product: { name: "", price: "10", vat_rate: "20", item_type: "product", category_id: "cat-1", active: "1" } }
          assert_response :unprocessable_entity
        end
      end
    end
  end

  test "products update renders validation error on invalid payload" do
    error = ServiceErrors::Validation.new(user_message: "gecersiz fiyat")
    fake_use_case = FakeProductsUpdateUseCase.new(error: error)

    with_authenticated_context(role: Roles::OPERATOR) do
      with_stubbed_constructor(Products::UpdateProduct, fake_use_case) do
        with_stubbed_constructor(Categories::OptionsQuery, FakeCategoriesOptionsQuery.new) do
          patch product_path("prd-1"), params: { product: { name: "Test", price: "-1", vat_rate: "20", item_type: "product", category_id: "cat-1", active: "1" } }
          assert_response :unprocessable_entity
        end
      end
    end
  end

  test "viewer cannot access offers index" do
    with_authenticated_context(role: Roles::VIEWER) do
      get offers_path
      assert_redirected_to root_path
    end
  end

  test "operator can access offers index" do
    with_authenticated_context(role: Roles::OPERATOR) do
      with_stubbed_constructor(Offers::IndexQuery, FakeOffersIndexQuery.new) do
        get offers_path
        assert_response :success
      end
    end
  end

  test "offers create renders validation error on invalid payload" do
    error = ServiceErrors::Validation.new(user_message: "kalemler gecersiz")
    fake_use_case = FakeOffersCreateUseCase.new(error: error)

    with_authenticated_context(role: Roles::OPERATOR) do
      with_stubbed_constructor(Offers::CreateOffer, fake_use_case) do
        post offers_path,
             params: {
               offer: {
                 company_id: "cmp-1",
                 offer_number: "TK-1",
                 offer_date: Date.current.iso8601,
                 status: "taslak",
                 items: []
               }
             }
        assert_response :unprocessable_entity
      end
    end
  end
end
