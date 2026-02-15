require "application_system_test_case"

class CriticalUserJourneyTest < ApplicationSystemTestCase
  driven_by :rack_test

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
      { "id" => @user_id, "email" => "operator@example.com" }
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

      { "id" => @user_id, "email" => "operator@example.com", "role" => @role, "active" => true }
    end
  end

  class FakeCompaniesIndexQuery
    def call(params:, **_kwargs)
      {
        items: [],
        scope: "active",
        page: 1,
        per_page: 50,
        has_prev: false,
        has_next: false
      }
    end
  end

  class FakeCreateCompanyUseCase
    attr_reader :calls

    def initialize
      @calls = []
    end

    def call(form_payload:, actor_id:)
      @calls << { form_payload: form_payload, actor_id: actor_id }
      { id: "cmp-1", notice: "Musteri olusturuldu." }
    end
  end

  setup do
    @constructor_restorers = []
  end

  teardown do
    @constructor_restorers.reverse_each(&:call)
  end

  test "operator can login and create company from new form" do
    user_id = "usr-system-1"
    fake_create_use_case = FakeCreateCompanyUseCase.new

    stub_constructor(Supabase::Auth, FakeAuth.new(user_id: user_id))
    stub_constructor(Auth::SessionRefresh, FakeSessionRefresh.new)
    stub_constructor(Users::Repository, FakeUsersRepository.new(user_id: user_id, role: Roles::OPERATOR))
    stub_constructor(Companies::IndexQuery, FakeCompaniesIndexQuery.new)
    stub_constructor(Catalog::UseCases::Companies::Create, fake_create_use_case)

    visit login_path
    fill_in "email", with: "operator@example.com"
    fill_in "password", with: "Password12"
    find("input[type='submit']").click

    assert_current_path(root_path)

    visit new_company_path
    fill_in "company_name", with: "Acme Ltd"
    fill_in "company_tax_number", with: "1234567890"
    fill_in "company_tax_office", with: "Kadikoy"
    fill_in "company_authorized_person", with: "Jane Doe"
    fill_in "company_phone", with: "5551234567"
    fill_in "company_email", with: "contact@acme.test"
    fill_in "company_address", with: "Istanbul"
    find("input[type='submit']").click

    assert_current_path(companies_path)
    assert_text "Musteri olusturuldu."
    assert_equal 1, fake_create_use_case.calls.size
    assert_equal user_id, fake_create_use_case.calls.first[:actor_id]
    assert_equal "Acme Ltd", fake_create_use_case.calls.first[:form_payload][:name]
  end

  private

  def stub_constructor(klass, instance)
    original_new = klass.method(:new)
    klass.singleton_class.send(:define_method, :new) do |*args, **kwargs, &blk|
      instance
    end

    @constructor_restorers << lambda do
      klass.singleton_class.send(:define_method, :new) do |*args, **kwargs, &blk|
        original_new.call(*args, **kwargs, &blk)
      end
    end
  end
end
