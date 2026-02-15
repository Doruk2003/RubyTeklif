module Auth
  class SendRecoveryEmailJob < ApplicationJob
    queue_as :mailers

    retry_on Supabase::Auth::AuthError, wait: 15.seconds, attempts: 3

    def perform(email)
      Supabase::Auth.new.send_recovery(email: email.to_s)
    end
  end
end
