require "test_helper"

class NewsletterFormTokenTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper
  include AntiSpamHelper

  FOOTER_FORM = "footer form[action='/newsletter_subscribers']".freeze

  def rendered_form_fields(page = root_path)
    get page
    assert_response :success
    hidden_fields_in(FOOTER_FORM)
  end

  def subscribe(fields, email: "reader@example.com")
    post newsletter_subscribers_path, params: fields.merge(email: email), headers: { "HTTP_REFERER" => root_path }
  end

  def assert_rejected_as_spam
    assert_no_difference "NewsletterSubscriber.count" do
      assert_no_enqueued_emails { yield }
    end
    assert_response :see_other
    assert_match "couldn't accept that submission", flash[:alert]
  end

  test "a visitor who fills in the footer form is subscribed and sent a confirmation" do
    fields = rendered_form_fields(chris_path)
    travel 5.seconds

    assert_difference "NewsletterSubscriber.count", 1 do
      assert_enqueued_emails(1) { subscribe(fields) }
    end
  end

  test "a submission posted without loading the form is rejected and sends no email" do
    assert_rejected_as_spam { subscribe({}) }
  end

  test "a submission with a forged token is rejected" do
    fields = rendered_form_fields
    travel 5.seconds
    forged = fields.transform_values { |value| value.to_s.reverse }

    assert_rejected_as_spam { subscribe(forged) }
    assert_rejected_as_spam { subscribe(fields.transform_values { "garbage" }) }
  end

  test "a submission sent faster than a person could fill in the form is rejected" do
    fields = rendered_form_fields
    travel 1.second

    assert_rejected_as_spam { subscribe(fields) }
  end

  test "a form left open for more than a day is rejected" do
    fields = rendered_form_fields
    travel 1.day + 1.minute

    assert_rejected_as_spam { subscribe(fields) }
  end

  test "a rendered form can only be submitted once" do
    fields = rendered_form_fields
    travel 5.seconds
    assert_difference("NewsletterSubscriber.count", 1) { subscribe(fields, email: "first@example.com") }

    assert_rejected_as_spam { subscribe(fields, email: "second@example.com") }
  end

  test "each page load gets its own token" do
    first = rendered_form_fields
    second = rendered_form_fields
    travel 5.seconds

    assert_difference "NewsletterSubscriber.count", 2 do
      subscribe(first, email: "first@example.com")
      subscribe(second, email: "second@example.com")
    end
  end
end
