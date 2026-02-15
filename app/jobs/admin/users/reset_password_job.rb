module Admin
  module Users
    class ResetPasswordJob < ApplicationJob
      queue_as :default

      retry_on ServiceErrors::System, wait: 10.seconds, attempts: 3

      discard_on ServiceErrors::Validation do |_job, error|
        Observability::ErrorReporter.report(
          error,
          severity: :warn,
          context: { source: "jobs/admin/users/reset_password" }
        )
      end

      def perform(target_user_id, actor_id)
        Admin::Users::UseCases::ResetUserPassword.new(client: Supabase::Client.new(role: :service)).call(
          id: target_user_id,
          actor_id: actor_id
        )
      end
    end
  end
end

