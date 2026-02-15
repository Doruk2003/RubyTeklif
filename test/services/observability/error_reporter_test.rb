require "test_helper"

module Observability
  class ErrorReporterTest < ActiveSupport::TestCase
    FakeScope = Struct.new(:tags, :contexts) do
      def initialize
        self.tags = {}
        self.contexts = {}
      end

      def set_tags(payload)
        self.tags = payload
      end

      def set_context(key, value)
        contexts[key] = value
      end
    end

    def with_env(key, value)
      previous = ENV[key]
      ENV[key] = value
      yield
    ensure
      ENV[key] = previous
    end

    def with_stubbed_singleton_method(object, method_name, replacement_proc)
      original = object.method(method_name)
      object.singleton_class.send(:define_method, method_name, &replacement_proc)
      yield
    ensure
      object.singleton_class.send(:define_method, method_name) do |*args, **kwargs, &blk|
        original.call(*args, **kwargs, &blk)
      end
    end

    test "warn severity logs warning and skips sentry for validation errors" do
      logged = []
      captured = []

      with_env("SENTRY_DSN", "http://example.invalid/1") do
        with_stubbed_singleton_method(Observability::AppLogger, :warn, ->(event, payload = {}) { logged << [event, payload] }) do
          with_stubbed_singleton_method(Observability::AppLogger, :error, ->(_event, _payload = {}) {}) do
            with_stubbed_singleton_method(Sentry, :with_scope, ->(&blk) { blk.call(FakeScope.new) }) do
              with_stubbed_singleton_method(Sentry, :capture_exception, ->(error) { captured << error }) do
                Observability::ErrorReporter.report(
                  ServiceErrors::Validation.new(user_message: "invalid"),
                  severity: :warn,
                  context: { source: "test" }
                )
              end
            end
          end
        end
      end

      assert_equal 1, logged.size
      assert_equal "app.error", logged.first.first
      assert_equal 0, captured.size
    end

    test "error severity logs and captures non-service exceptions in sentry" do
      logged = []
      captured = []
      last_scope = nil

      Current.request_id = "req-1"
      Current.user = CurrentUser.new(id: "usr-1", role: Roles::ADMIN, name: "admin@example.com")

      with_env("SENTRY_DSN", "http://example.invalid/1") do
        with_stubbed_singleton_method(Observability::AppLogger, :error, ->(event, payload = {}) { logged << [event, payload] }) do
          with_stubbed_singleton_method(Sentry, :with_scope, lambda { |&blk|
            scope = FakeScope.new
            last_scope = scope
            blk.call(scope)
          }) do
            with_stubbed_singleton_method(Sentry, :capture_exception, ->(error) { captured << error }) do
              error = RuntimeError.new("boom")
              Observability::ErrorReporter.report(error, severity: :error, context: { source: "test" })
            end
          end
        end
      end

      assert_equal 1, logged.size
      assert_equal 1, captured.size
      assert_equal "boom", captured.first.message
      assert_equal "req-1", last_scope.tags[:request_id]
      assert_equal "usr-1", last_scope.tags[:user_id]
      assert_equal "error", last_scope.tags[:severity]
      assert_equal "test", last_scope.contexts["app_context"]["source"]
    ensure
      Current.reset
    end
  end
end
