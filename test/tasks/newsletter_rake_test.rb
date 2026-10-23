require "test_helper"
require "rake"

class NewsletterRakeTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("newsletter:send_confirmations")
    @task = Rake::Task["newsletter:send_confirmations"]
    @task.reenable
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
end
