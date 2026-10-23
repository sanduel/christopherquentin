require "test_helper"

class ResendNewsletterSyncJobTest < ActiveJob::TestCase
  include NewsletterHelper

  {
    "rate limited" => { status: 429, body: { statusCode: 429, name: "rate_limit_exceeded", message: "Too many requests" }.to_json,
                        headers: { "Content-Type" => "application/json", "retry-after" => "1" } },
    "a server error" => { status: 500, body: { statusCode: 500, name: "internal_server_error", message: "Oops" }.to_json,
                          headers: { "Content-Type" => "application/json" } },
    "a non-JSON gateway error" => { status: 502, body: "<html>Bad Gateway</html>", headers: { "Content-Type" => "text/html" } }
  }.each do |label, response|
    test "#{label} response is retried later instead of failing" do
      stub_request(:get, resend_contact_url("fan@test.com")).to_return(response)

      assert_enqueued_with(job: ResendNewsletterSyncJob, args: [ "fan@test.com" ]) do
        ResendNewsletterSyncJob.perform_now("fan@test.com")
      end
    end
  end

  test "a network timeout is retried later instead of failing" do
    stub_request(:get, resend_contact_url("fan@test.com")).to_timeout

    assert_enqueued_with(job: ResendNewsletterSyncJob, args: [ "fan@test.com" ]) do
      ResendNewsletterSyncJob.perform_now("fan@test.com")
    end
  end
end
