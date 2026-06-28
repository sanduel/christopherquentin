require "test_helper"

class NewsletterSubscribersControllerTest < ActionDispatch::IntegrationTest
  test "POST with footer form params creates a subscriber and redirects with notice" do
    assert_difference "NewsletterSubscriber.count", 1 do
      post newsletter_subscribers_path, params: { email: "fan@test.com" },
           headers: { "HTTP_REFERER" => root_path }
    end
    assert_equal "fan@test.com", NewsletterSubscriber.last.email
    assert_redirected_to root_path
    assert_equal "Thank you for subscribing!", flash[:notice]
  end

  test "POST with invalid email does not create a subscriber and redirects with alert" do
    assert_no_difference "NewsletterSubscriber.count" do
      post newsletter_subscribers_path, params: { email: "not-an-email" },
           headers: { "HTTP_REFERER" => root_path }
    end
    assert_redirected_to root_path
    assert_match(/could not subscribe/i, flash[:alert])
  end
end
