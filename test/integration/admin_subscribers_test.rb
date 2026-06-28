require "test_helper"

class AdminSubscribersTest < ActionDispatch::IntegrationTest
  include SignInHelper

  test "non-admin cannot access subscribers index" do
    sign_in_contributor
    get admin_newsletter_subscribers_path
    assert_redirected_to root_path
  end

  test "admin can view subscribers index" do
    sign_in_admin
    NewsletterSubscriber.create!(email: "fan@test.com")

    get admin_newsletter_subscribers_path
    assert_response :success
    assert_select "body", text: /fan@test\.com/
  end

  test "non-admin cannot delete a subscriber" do
    sign_in_contributor
    subscriber = NewsletterSubscriber.create!(email: "fan@test.com")

    assert_no_difference -> { NewsletterSubscriber.count } do
      delete admin_newsletter_subscriber_path(subscriber)
    end
    assert_redirected_to root_path
  end

  test "admin can delete a subscriber" do
    sign_in_admin
    subscriber = NewsletterSubscriber.create!(email: "fan@test.com")

    assert_difference -> { NewsletterSubscriber.count }, -1 do
      delete admin_newsletter_subscriber_path(subscriber)
    end
    assert_redirected_to admin_newsletter_subscribers_path
  end

  test "admin can export subscribers as CSV" do
    sign_in_admin
    NewsletterSubscriber.create!(email: "fan@test.com")

    get admin_newsletter_subscribers_path(format: :csv)
    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_includes response.body, "fan@test.com"
  end
end
