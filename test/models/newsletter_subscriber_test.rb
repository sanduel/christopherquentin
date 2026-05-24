require "test_helper"

class NewsletterSubscriberTest < ActiveSupport::TestCase
  test "valid with email" do
    sub = NewsletterSubscriber.new(email: "test@example.com")
    assert sub.valid?
  end

  test "invalid without email" do
    sub = NewsletterSubscriber.new
    assert_not sub.valid?
  end

  test "invalid with bad email format" do
    sub = NewsletterSubscriber.new(email: "notanemail")
    assert_not sub.valid?
  end

  test "email must be unique" do
    NewsletterSubscriber.create!(email: "test@example.com")
    sub = NewsletterSubscriber.new(email: "test@example.com")
    assert_not sub.valid?
  end
end
