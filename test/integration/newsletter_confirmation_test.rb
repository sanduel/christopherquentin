require "test_helper"

class NewsletterConfirmationTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper
  include NewsletterHelper

  setup do
    post newsletter_subscribers_path, params: { email: "fan@test.com" }
    perform_enqueued_jobs
    @subscriber = NewsletterSubscriber.find_by!(email: "fan@test.com")
    @path = confirmation_path_from(ActionMailer::Base.deliveries.last)
  end

  test "opening the link shows a confirm button but does not confirm" do
    get @path

    assert_response :success
    assert_select "form[action='#{@path}'][method=post]"
    assert_nil @subscriber.reload.confirmed_at
  end

  test "pressing confirm confirms the subscriber and adds them to the Resend newsletter segment" do
    get_contact = stub_request(:get, resend_contact_url("fan@test.com"))
      .to_return(status: 404, body: { statusCode: 404, name: "not_found", message: "Contact not found" }.to_json,
                 headers: { "Content-Type" => "application/json" })
    create_contact = stub_request(:post, "#{RESEND_API}/contacts")
      .with(body: hash_including(email: "fan@test.com", unsubscribed: false, segments: [ { id: SEGMENT_ID } ]))
      .to_return(status: 201, body: { object: "contact", id: "c_1" }.to_json, headers: { "Content-Type" => "application/json" })

    perform_enqueued_jobs { post @path }

    assert_not_nil @subscriber.reload.confirmed_at
    assert_requested get_contact
    assert_requested create_contact
    assert_response :success
    assert_match(/you're subscribed/i, response.body)
  end

  test "confirming an address Resend already knows re-subscribes it and adds it to the segment" do
    stub_request(:get, resend_contact_url("fan@test.com"))
      .to_return(status: 200, body: { object: "contact", id: "c_1", email: "fan@test.com", unsubscribed: true }.to_json,
                 headers: { "Content-Type" => "application/json" })
    resubscribe = stub_request(:patch, resend_contact_url("fan@test.com"))
      .with(body: hash_including(unsubscribed: false))
      .to_return(status: 200, body: { object: "contact", id: "c_1" }.to_json, headers: { "Content-Type" => "application/json" })
    add_to_segment = stub_request(:post, resend_segment_membership_url("fan@test.com"))
      .to_return(status: 200, body: { id: SEGMENT_ID }.to_json, headers: { "Content-Type" => "application/json" })

    perform_enqueued_jobs { post @path }

    assert_requested resubscribe
    assert_requested add_to_segment
  end

  test "the link stops working once used" do
    stub_request(:any, /api\.resend\.com/).to_return(status: 404, body: { statusCode: 404, name: "not_found", message: "Contact not found" }.to_json, headers: { "Content-Type" => "application/json" })
    stub_request(:post, "#{RESEND_API}/contacts").to_return(status: 201, body: "{}", headers: { "Content-Type" => "application/json" })
    perform_enqueued_jobs { post @path }

    get @path
    assert_response :not_found
    assert_match(/expired/i, response.body)
  end

  test "the link expires after 14 days" do
    travel 15.days

    get @path
    assert_response :not_found

    post @path
    assert_response :not_found
    assert_nil @subscriber.reload.confirmed_at
  end

  test "a garbage token is not found" do
    get "/newsletter/confirm/not-a-token"
    assert_response :not_found
  end
end
