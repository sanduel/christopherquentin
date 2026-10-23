require "test_helper"

class MailerDefaultsTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  FROM = "hello@send.christopherquentin.com".freeze
  REPLY_TO = "samuelmcmullen@gmail.com".freeze

  test "password reset emails come from the site address with replies to a real inbox" do
    User.create!(name: "Jane", email: "jane@test.com", password: "password123")

    assert_enqueued_emails 1 do
      post user_password_path, params: { user: { email: "jane@test.com" } }
    end
    assert_redirected_to new_user_session_path
    perform_enqueued_jobs

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ FROM ], mail.from
    assert_equal "Christopher Quentin", mail[:from].display_names.first
    assert_equal [ REPLY_TO ], mail.reply_to
  end

  test "newsletter confirmation emails come from the site address with replies to a real inbox" do
    post newsletter_subscribers_path, params: { email: "fan@test.com" }
    perform_enqueued_jobs

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ FROM ], mail.from
    assert_equal [ REPLY_TO ], mail.reply_to
  end
end
