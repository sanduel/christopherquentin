require "test_helper"
require "rake"

class NewsletterRakeTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  include ActiveJob::TestHelper

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("newsletter:send_confirmations")
    @task = Rake::Task["newsletter:send_confirmations"]
    @task.reenable
    ActionMailer::Base.deliveries.clear
  end

  test "emails each unconfirmed subscriber who has not been sent a confirmation, once" do
    pending_a = NewsletterSubscriber.create!(email: "a@test.com")
    pending_b = NewsletterSubscriber.create!(email: "b@test.com")
    NewsletterSubscriber.create!(email: "confirmed@test.com", confirmed_at: 1.day.ago)
    NewsletterSubscriber.create!(email: "already-sent@test.com", confirmation_sent_at: 1.day.ago)

    assert_emails 2 do
      assert_output(/Sent 2/) { @task.invoke }
    end
    assert_equal %w[a@test.com b@test.com], ActionMailer::Base.deliveries.flat_map(&:to).sort
    assert_not_nil pending_a.reload.confirmation_sent_at
    assert_not_nil pending_b.reload.confirmation_sent_at

    @task.reenable
    assert_no_emails do
      assert_output(/Sent 0/) { @task.invoke }
    end
  end

  test "with real Resend delivery, a failure for one address does not stop the others" do
    bad = NewsletterSubscriber.create!(email: "bad@test.com")
    good = NewsletterSubscriber.create!(email: "good@test.com")
    stub_request(:post, "https://api.resend.com/emails")
      .with { |request| JSON.parse(request.body)["to"] == [ "bad@test.com" ] }
      .to_return(status: 422, body: { statusCode: 422, name: "validation_error", message: "Invalid `to` field" }.to_json,
                 headers: { "Content-Type" => "application/json" })
    delivered = stub_request(:post, "https://api.resend.com/emails")
      .with { |request| JSON.parse(request.body)["to"] == [ "good@test.com" ] }
      .to_return(status: 200, body: { id: "email_1" }.to_json, headers: { "Content-Type" => "application/json" })

    with_delivery_method(:resend) do
      assert_output(/Sent 1.*1 failed/m) { @task.invoke }
    end

    assert_requested delivered
    assert_nil bad.reload.confirmation_sent_at
    assert_not_nil good.reload.confirmation_sent_at
  end

  test "with real Resend delivery, a rate-limited send waits and is retried" do
    subscriber = NewsletterSubscriber.create!(email: "a@test.com")
    stub_request(:post, "https://api.resend.com/emails")
      .to_return({ status: 429, body: { statusCode: 429, name: "rate_limit_exceeded", message: "Too many requests" }.to_json,
                   headers: { "Content-Type" => "application/json", "retry-after" => "0" } },
                 { status: 200, body: { id: "email_1" }.to_json, headers: { "Content-Type" => "application/json" } })

    with_delivery_method(:resend) do
      assert_output(/Sent 1.*0 failed/m) { @task.invoke }
    end

    assert_not_nil subscriber.reload.confirmation_sent_at
  end

  test "resync re-queues every confirmed subscriber for the Resend segment" do
    NewsletterSubscriber.create!(email: "a@test.com", confirmed_at: 1.day.ago)
    NewsletterSubscriber.create!(email: "pending@test.com")
    resync = Rake::Task["newsletter:resync"]
    resync.reenable

    assert_enqueued_with(job: ResendNewsletterSyncJob, args: [ "a@test.com" ]) do
      assert_output(/Queued 1/) { resync.invoke }
    end
    assert_enqueued_jobs 1, only: ResendNewsletterSyncJob
  end

  private

  def with_delivery_method(method)
    original = ActionMailer::Base.delivery_method
    ActionMailer::Base.delivery_method = method
    yield
  ensure
    ActionMailer::Base.delivery_method = original
  end
end
