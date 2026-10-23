require "test_helper"

class ResendNewsletterSyncJobTest < ActiveJob::TestCase
  include NewsletterHelper

  test "a rate-limited request is retried later instead of failing" do
    subscriber = NewsletterSubscriber.create!(email: "fan@test.com", confirmed_at: Time.current)
    stub_request(:get, resend_contact_url("fan@test.com"))
      .to_return(status: 429, body: { statusCode: 429, name: "rate_limit_exceeded", message: "Too many requests" }.to_json,
                 headers: { "Content-Type" => "application/json", "retry-after" => "1" })

    assert_enqueued_with(job: ResendNewsletterSyncJob, args: [ subscriber ]) do
      ResendNewsletterSyncJob.perform_now(subscriber)
    end
  end
end
