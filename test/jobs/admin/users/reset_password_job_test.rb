require "test_helper"

module Admin
  module Users
    class ResetPasswordJobTest < ActiveSupport::TestCase
      class FakeResetPasswordService
        attr_reader :calls

        def initialize(error: nil)
          @error = error
          @calls = []
        end

        def call(id:, actor_id:)
          raise @error if @error

          @calls << { id: id, actor_id: actor_id }
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

      test "delegates to reset password service" do
        fake_service = FakeResetPasswordService.new

        with_stubbed_constructor(Admin::Users::ResetPassword, fake_service) do
          with_stubbed_constructor(Supabase::Client, Object.new) do
            ResetPasswordJob.perform_now("usr-2", "usr-1")
          end
        end

        assert_equal [{ id: "usr-2", actor_id: "usr-1" }], fake_service.calls
      end

      test "discards validation errors" do
        fake_service = FakeResetPasswordService.new(error: ServiceErrors::Validation.new(user_message: "email yok"))

        with_stubbed_constructor(Admin::Users::ResetPassword, fake_service) do
          with_stubbed_constructor(Supabase::Client, Object.new) do
            assert_nothing_raised do
              ResetPasswordJob.perform_now("usr-2", "usr-1")
            end
          end
        end
      end
    end
  end
end
