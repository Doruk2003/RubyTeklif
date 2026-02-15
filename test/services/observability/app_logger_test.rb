require "test_helper"
require "json"

module Observability
  class AppLoggerTest < ActiveSupport::TestCase
    class FakeLogger
      attr_reader :lines

      def initialize
        @lines = []
      end

      def info(message)
        @lines << message
      end
    end

    test "includes current context in structured log line" do
      fake_logger = FakeLogger.new
      original_logger = Rails.logger
      original_env = Rails.env
      Current.user = CurrentUser.new(id: "usr-1", role: Roles::ADMIN, name: "user@example.com")
      Current.request_id = "req-1"

      Rails.singleton_class.send(:define_method, :logger) { fake_logger }
      Rails.singleton_class.send(:define_method, :env) { ActiveSupport::StringInquirer.new("test") }

      AppLogger.info("sample.event", { foo: "bar" })
      parsed = JSON.parse(fake_logger.lines.first)

      assert_equal "sample.event", parsed["event"]
      assert_equal "info", parsed["severity"]
      assert_equal "test", parsed["env"]
      assert_equal "req-1", parsed["request_id"]
      assert_equal "usr-1", parsed["user_id"]
      assert_equal "bar", parsed["foo"]
    ensure
      Current.reset
      Rails.singleton_class.send(:define_method, :logger) { original_logger }
      Rails.singleton_class.send(:define_method, :env) { original_env }
    end
  end
end
