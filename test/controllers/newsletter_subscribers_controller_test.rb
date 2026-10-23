require "test_helper"

class NewsletterSubscribersControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper
  include NewsletterHelper

  def subscribe(email)
    post newsletter_subscribers_path, params: { email: email }, headers: { "HTTP_REFERER" => root_path }
  end

  test "a new email creates an unconfirmed subscriber and is sent a confirmation link" do
    assert_difference "NewsletterSubscriber.count", 1 do
      assert_enqueued_emails 1 do
        subscribe "fan@test.com"
      end
    end

    subscriber = NewsletterSubscriber.find_by!(email: "fan@test.com")
    assert_nil subscriber.confirmed_at
    assert_not_nil subscriber.confirmation_sent_at
    assert_redirected_to root_path
    assert_match(/check your email/i, flash[:notice])

    perform_enqueued_jobs
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "fan@test.com" ], mail.to
    get confirmation_path_from(mail)
    assert_response :success
  end

  test "an email is normalized before it is stored" do
    subscribe "  Fan@Test.COM "
    assert NewsletterSubscriber.exists?(email: "fan@test.com")
  end

  test "an unconfirmed email signing up again gets a fresh confirmation and no duplicate" do
    NewsletterSubscriber.create!(email: "fan@test.com")

    assert_no_difference "NewsletterSubscriber.count" do
      assert_enqueued_emails 1 do
        subscribe "FAN@test.com"
      end
    end
    assert_match(/check your email/i, flash[:notice])
  end

  test "a confirmed email signing up again sees the same message and is not emailed" do
    NewsletterSubscriber.create!(email: "fan@test.com", confirmed_at: 1.day.ago)

    assert_no_difference "NewsletterSubscriber.count" do
      assert_no_enqueued_emails do
        subscribe "fan@test.com"
      end
    end
    assert_match(/check your email/i, flash[:notice])
  end

  test "an invalid email is rejected and nothing is sent" do
    assert_no_difference "NewsletterSubscriber.count" do
      assert_no_enqueued_emails do
        subscribe "not-an-email"
      end
    end
    assert_redirected_to root_path
    assert_match(/could not subscribe/i, flash[:alert])
  end
end
