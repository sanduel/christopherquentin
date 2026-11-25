require "test_helper"

class FormRenderTokenTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper
  include AntiSpamHelper

  ENDPOINTS = {
    newsletter_subscriber: {
      form_page: -> { chris_path },
      form: "footer form[action='/newsletter_subscribers']",
      action: -> { newsletter_subscribers_path },
      params: ->(email) { { email: email } },
      model: "NewsletterSubscriber"
    },
    registration: {
      form_page: -> { new_user_registration_path },
      form: "form[action='/users']",
      action: -> { user_registration_path },
      params: ->(email) { { user: { name: "Jane", email: email, password: "password123", password_confirmation: "password123" } } },
      model: "User"
    }
  }.freeze

  def rendered_form_fields(endpoint)
    get instance_exec(&endpoint[:form_page])
    assert_response :success
    hidden_fields_in(endpoint[:form])
  end

  def submit(endpoint, fields, email: "reader@example.com")
    post instance_exec(&endpoint[:action]),
      params: fields.merge(instance_exec(email, &endpoint[:params])),
      headers: { "HTTP_REFERER" => root_path }
    # A successful registration signs the user in; sign out so the next attempt is anonymous.
    delete destroy_user_session_path if endpoint[:model] == "User"
  end

  def assert_rejected_as_spam(endpoint)
    assert_no_difference endpoint[:model] + ".count" do
      assert_no_enqueued_emails { yield }
    end
    assert_match "couldn't accept that submission", flash[:alert]
  end

  test "registration: a visitor who mistypes their password can correct it and sign up" do
    endpoint = ENDPOINTS[:registration]
    fields = rendered_form_fields(endpoint)
    travel 5.seconds
    post user_registration_path, params: fields.merge(
      user: { name: "Jane", email: "jane@example.com", password: "password123", password_confirmation: "password124" })
    assert_response :unprocessable_entity

    retry_fields = hidden_fields_in(endpoint[:form])
    travel 5.seconds
    assert_difference("User.count", 1) { submit(endpoint, retry_fields, email: "jane@example.com") }
  end

  ENDPOINTS.each do |key, endpoint|
    test "#{key}: a visitor who fills in the rendered form gets through" do
      fields = rendered_form_fields(endpoint)
      travel 5.seconds

      assert_difference("#{endpoint[:model]}.count", 1) { submit(endpoint, fields) }
    end

    test "#{key}: a submission posted without loading the form is rejected" do
      assert_rejected_as_spam(endpoint) { submit(endpoint, {}) }
    end

    test "#{key}: a submission with a forged token is rejected" do
      fields = rendered_form_fields(endpoint)
      travel 5.seconds

      assert_rejected_as_spam(endpoint) { submit(endpoint, fields.transform_values { |value| value.to_s.reverse }) }
      assert_rejected_as_spam(endpoint) { submit(endpoint, fields.transform_values { "garbage" }) }
    end

    test "#{key}: a submission sent faster than a person could fill in the form is rejected" do
      fields = rendered_form_fields(endpoint)
      travel 1.second

      assert_rejected_as_spam(endpoint) { submit(endpoint, fields) }
    end

    test "#{key}: a form left open for more than a day is rejected" do
      fields = rendered_form_fields(endpoint)
      travel 1.day + 1.minute

      assert_rejected_as_spam(endpoint) { submit(endpoint, fields) }
    end

    test "#{key}: a rendered form can only be submitted once" do
      fields = rendered_form_fields(endpoint)
      travel 5.seconds
      assert_difference("#{endpoint[:model]}.count", 1) { submit(endpoint, fields, email: "first@example.com") }

      assert_rejected_as_spam(endpoint) { submit(endpoint, fields, email: "second@example.com") }
    end

    test "#{key}: each page load gets its own token" do
      first = rendered_form_fields(endpoint)
      second = rendered_form_fields(endpoint)
      travel 5.seconds

      assert_difference "#{endpoint[:model]}.count", 2 do
        submit(endpoint, first, email: "first@example.com")
        submit(endpoint, second, email: "second@example.com")
      end
    end
  end
end
