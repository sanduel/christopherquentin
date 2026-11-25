require "test_helper"
require "rake"

class NewsletterPurgeExpiredRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("newsletter:purge_expired")
    @purge = Rake::Task["newsletter:purge_expired"]
    @purge.reenable
  end

  test "deletes unconfirmed sign-ups whose confirmation link has expired and keeps everything else" do
    expired = NewsletterSubscriber.create!(email: "expired@example.com", confirmation_sent_at: 16.days.ago)
    pending = NewsletterSubscriber.create!(email: "pending@example.com", confirmation_sent_at: 13.days.ago)
    confirmed = NewsletterSubscriber.create!(email: "confirmed@example.com", confirmation_sent_at: 30.days.ago, confirmed_at: 29.days.ago)
    never_emailed = NewsletterSubscriber.create!(email: "legacy@example.com", confirmation_sent_at: nil, created_at: 1.year.ago)

    assert_output(/Deleted 1 /) { @purge.invoke }

    assert_not NewsletterSubscriber.exists?(expired.id)
    assert NewsletterSubscriber.exists?(pending.id)
    assert NewsletterSubscriber.exists?(confirmed.id)
    assert NewsletterSubscriber.exists?(never_emailed.id)
  end

  test "an expired sign-up's confirmation link no longer works, so purging it loses nothing" do
    subscriber = NewsletterSubscriber.create!(email: "expired@example.com", confirmation_sent_at: Time.current)
    token = subscriber.generate_token_for(:confirmation)

    travel NewsletterSubscriber::CONFIRMATION_LINK_LIFETIME + 2.days
    assert_nil NewsletterSubscriber.find_by_token_for(:confirmation, token)
    assert_includes NewsletterSubscriber.confirmation_expired, subscriber
  end
end
