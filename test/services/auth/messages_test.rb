require "test_helper"

module Auth
  class MessagesTest < ActiveSupport::TestCase
    MESSAGE_CONSTANTS = [
      :SESSION_TIMEOUT,
      :SESSION_ENDED,
      :SESSION_REFRESH_FAILED,
      :ACCOUNT_DISABLED,
      :UNAUTHORIZED,
      :LOGIN_FAILED_PREFIX,
      :RECOVERY_EMAIL_REQUIRED,
      :RECOVERY_SENT,
      :RECOVERY_FAILED_PREFIX,
      :UNEXPECTED_ERROR
    ].freeze

    test "all auth messages are valid utf-8 and non-empty" do
      MESSAGE_CONSTANTS.each do |constant|
        value = Auth::Messages.const_get(constant)
        assert value.is_a?(String), "#{constant} should be a String"
        assert value.present?, "#{constant} should not be blank"
        assert_equal Encoding::UTF_8, value.encoding, "#{constant} should be UTF-8"
        assert value.valid_encoding?, "#{constant} has invalid encoding"
      end
    end
  end
end
