require "test_helper"

module Auth
  class SendRecoveryEmailJobTest < ActiveSupport::TestCase
    class FakeAuth
      attr_reader :calls

      def initialize
        @calls = []
      end

      def send_recovery(email:)
        @calls << email
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

    test "delegates recovery email to supabase auth" do
      fake_auth = FakeAuth.new

      with_stubbed_constructor(Supabase::Auth, fake_auth) do
        Auth::SendRecoveryEmailJob.perform_now("user@example.com")
      end

      assert_equal ["user@example.com"], fake_auth.calls
    end
  end
end
