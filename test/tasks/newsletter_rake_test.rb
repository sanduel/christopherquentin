require "test_helper"
require "rake"

class NewsletterRakeTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  include ActiveJob::TestHelper
  include NewsletterHelper

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("newsletter:import_existing")
    @import = Rake::Task["newsletter:import_existing"]
    @import.reenable
  end

  def stub_new_contact(email)
    stub_request(:get, resend_contact_url(email))
      .to_return(status: 404, body: { statusCode: 404, name: "not_found", message: "Contact not found" }.to_json,
                 headers: { "Content-Type" => "application/json" })
    stub_request(:post, "#{RESEND_API}/contacts")
      .with(body: hash_including(email: email, segments: [ { id: SEGMENT_ID } ]))
      .to_return(status: 201, body: { object: "contact", id: "c_#{email}" }.to_json, headers: { "Content-Type" => "application/json" })
  end

  def import(ids)
    ENV["IDS"] = ids.join(",")
    @import.invoke
  ensure
    ENV.delete("IDS")
  end

  test "imports only the listed subscribers: confirmed and in the Resend segment, with no email sent" do
    listed = NewsletterSubscriber.create!(email: "a@test.com")
    unlisted = NewsletterSubscriber.create!(email: "suspect@test.com")
    created = stub_new_contact("a@test.com")

    assert_no_emails do
      assert_output(/Imported 1, 0 failed/) { import([ listed.id ]) }
    end

    assert_requested created
    assert_not_nil listed.reload.confirmed_at
    assert_nil unlisted.reload.confirmed_at
    assert_not_requested :any, %r{contacts/suspect@test\.com}
  end

  test "a subscriber whose sync fails stays unconfirmed and the rest still import" do
    bad = NewsletterSubscriber.create!(email: "bad@test.com")
    good = NewsletterSubscriber.create!(email: "good@test.com")
    stub_request(:get, resend_contact_url("bad@test.com"))
      .to_return(status: 422, body: { statusCode: 422, name: "validation_error", message: "Invalid email" }.to_json,
                 headers: { "Content-Type" => "application/json" })
    stub_new_contact("good@test.com")

    assert_output(/Imported 1, 1 failed/, /bad@test\.com/) { import([ bad.id, good.id ]) }

    assert_nil bad.reload.confirmed_at
    assert_not_nil good.reload.confirmed_at
  end

  test "a rate-limited sync waits and is retried" do
    subscriber = NewsletterSubscriber.create!(email: "a@test.com")
    stub_request(:get, resend_contact_url("a@test.com"))
      .to_return({ status: 429, body: { statusCode: 429, name: "rate_limit_exceeded", message: "Too many requests" }.to_json,
                   headers: { "Content-Type" => "application/json", "retry-after" => "0" } },
                 { status: 404, body: { statusCode: 404, name: "not_found", message: "Contact not found" }.to_json,
                   headers: { "Content-Type" => "application/json" } })
    stub_request(:post, "#{RESEND_API}/contacts")
      .to_return(status: 201, body: { id: "c_1" }.to_json, headers: { "Content-Type" => "application/json" })

    assert_output(/Imported 1, 0 failed/) { import([ subscriber.id ]) }
    assert_not_nil subscriber.reload.confirmed_at
  end

  test "already confirmed subscribers are skipped, so re-running is safe" do
    subscriber = NewsletterSubscriber.create!(email: "a@test.com", confirmed_at: 1.day.ago)

    assert_output(/Imported 0, 0 failed/) { import([ subscriber.id ]) }
    assert_not_requested :any, /api\.resend\.com/
  end

  test "refuses to run without an explicit list of ids" do
    NewsletterSubscriber.create!(email: "a@test.com")

    assert_raises(KeyError) { @import.invoke }
    assert_equal 0, NewsletterSubscriber.confirmed.count
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
end
