require "test_helper"

class AdminSubscribersTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  include SignInHelper
  include NewsletterHelper

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

  test "admin sees whether each subscriber has confirmed" do
    sign_in_admin
    confirmed = NewsletterSubscriber.create!(email: "confirmed@test.com", confirmed_at: 1.day.ago)
    pending = NewsletterSubscriber.create!(email: "pending@test.com")

    get admin_newsletter_subscribers_path
    assert_select "##{dom_id(confirmed)}", text: /Confirmed/
    assert_select "##{dom_id(confirmed)}", text: /Pending/, count: 0
    assert_select "##{dom_id(pending)}", text: /Pending/
    assert_select "##{dom_id(pending)}", text: /Confirmed/, count: 0
  end

  test "deleting a confirmed subscriber removes them from the Resend newsletter segment" do
    sign_in_admin
    subscriber = NewsletterSubscriber.create!(email: "fan@test.com", confirmed_at: 1.day.ago)
    remove = stub_request(:delete, resend_segment_membership_url("fan@test.com"))
      .to_return(status: 200, body: { id: SEGMENT_ID, deleted: true }.to_json, headers: { "Content-Type" => "application/json" })

    perform_enqueued_jobs { delete admin_newsletter_subscriber_path(subscriber) }

    assert_requested remove
  end

  test "deleting an unconfirmed subscriber makes no Resend call" do
    sign_in_admin
    subscriber = NewsletterSubscriber.create!(email: "fan@test.com")

    perform_enqueued_jobs { delete admin_newsletter_subscriber_path(subscriber) }

    assert_not_requested :any, /api\.resend\.com/
  end

  test "admin can export subscribers as CSV" do
    sign_in_admin
    NewsletterSubscriber.create!(email: "fan@test.com")

    get admin_newsletter_subscribers_path(format: :csv)
    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_includes response.body, "fan@test.com"
  end

  test "CSV export neutralizes formula-injection in subscriber email" do
    sign_in_admin
    # A formula-prefixed local part still passes URI::MailTo::EMAIL_REGEXP.
    NewsletterSubscriber.create!(email: "=1+1@x.com")

    get admin_newsletter_subscribers_path(format: :csv)
    assert_response :success
    # The cell must be prefixed so spreadsheet apps treat it as text, not a formula.
    assert_includes response.body, "'=1+1@x.com"
    refute_match(/(^|,)"?=1\+1/, response.body)
  end
end
