require "test_helper"

class AdminActivityLogsControllerTest < ActionDispatch::IntegrationTest
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
      { "id" => @user_id, "email" => "admin@example.com" }
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

      { "id" => @user_id, "email" => "admin@example.com", "role" => @role, "active" => true }
    end
  end

  class FakeIndexQuery
    attr_reader :params

    def call(params:)
      @params = params
      { items: [], page: 1, per_page: 100, has_prev: false, has_next: false }
    end

    def action_options
      []
    end

    def target_type_options
      []
    end
  end

  class FakeClient
    def get(path)
      []
    end
  end

  class FakeExportJob
    attr_reader :calls

    def initialize
      @calls = []
    end

    def perform_later(token, actor_id, filters)
      @calls << { token: token, actor_id: actor_id, filters: filters }
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

  private def with_admin_auth
    user_id = "usr-admin"
    with_stubbed_constructor(Supabase::Auth, FakeAuth.new(user_id: user_id)) do
      with_stubbed_constructor(Auth::SessionRefresh, FakeSessionRefresh.new) do
        with_stubbed_constructor(Users::Repository, FakeUsersRepository.new(user_id: user_id, role: Roles::ADMIN)) do
          post login_path, params: { email: "admin@example.com", password: "Password12" }
          assert_redirected_to root_path
          yield user_id
        end
      end
    end
  end

  test "queues export job for admin" do
    fake_query = FakeIndexQuery.new
    fake_job = FakeExportJob.new

    with_admin_auth do |user_id|
      with_stubbed_constructor(Admin::ActivityLogs::IndexQuery, fake_query) do
        with_stubbed_constructor(Supabase::Client, FakeClient.new) do
          original_perform_later = Admin::ActivityLogs::ExportCsvJob.method(:perform_later)
          Admin::ActivityLogs::ExportCsvJob.singleton_class.send(:define_method, :perform_later) do |token, actor_id, filters|
            fake_job.perform_later(token, actor_id, filters)
          end

          post export_admin_activity_logs_path, params: { target_type: "user" }
          assert_redirected_to admin_activity_logs_path(target_type: "user")
          assert_equal 1, fake_job.calls.size
          assert_equal user_id, fake_job.calls.first[:actor_id]
        ensure
          Admin::ActivityLogs::ExportCsvJob.singleton_class.send(:define_method, :perform_later) do |token, actor_id, filters|
            original_perform_later.call(token, actor_id, filters)
          end
        end
      end
    end
  end
end
