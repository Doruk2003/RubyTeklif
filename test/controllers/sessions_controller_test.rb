require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "password recovery enqueues background job" do
    assert_enqueued_with(job: Auth::SendRecoveryEmailJob, args: ["user@example.com"]) do
      post "/password-recovery", params: { email: "user@example.com" }
    end

    assert_redirected_to "/login"
  end

  test "password recovery validates empty email" do
    assert_no_enqueued_jobs only: Auth::SendRecoveryEmailJob do
      post "/password-recovery", params: { email: "" }
    end

    assert_response :unprocessable_entity
  end
end
