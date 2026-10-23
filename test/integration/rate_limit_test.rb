require "test_helper"

class RateLimitTest < ActionDispatch::IntegrationTest
  RAILWAY_PROXY_IP = "100.64.0.5".freeze

  ENDPOINTS = {
    tribute: {
      limit: 10,
      action: -> { tributes_path },
      params: ->(i) { { tribute: { name: "Jane #{i}", relationship: "Friend", content: "A light." } } },
      model: "Tribute"
    },
    memory: {
      limit: 10,
      action: -> { memories_path },
      params: ->(i) { { memory: { date: "2010-05-01", content: "Memory #{i}", name: "Jane", email: "jane#{i}@example.com" } } },
      model: "Memory"
    },
    reply: {
      limit: 10,
      action: -> { memory_replies_path(memories(:hanover)) },
      params: ->(i) { { reply: { name: "Jane", email: "jane#{i}@example.com", body: "Reply #{i}" } } },
      model: "Reply"
    },
    tree: {
      limit: 10,
      action: -> { trees_path },
      params: ->(i) { { tree: { name: "Jane #{i}", email: "jane@example.com", address: "Ann Arbor, MI", tree_count: 1 } } },
      model: "Tree"
    },
    recipe: {
      limit: 10,
      action: -> { recipes_path },
      params: ->(i) { { recipe: { submitter_name: "Jane", title: "Soup #{i}", ingredients: "Water", instructions: "Boil" } } },
      model: "Recipe"
    },
    gallery_photo: {
      limit: 10,
      action: -> { submit_photos_path },
      params: ->(i) {
        { submitter_name: "Jane", submitter_email: "jane#{i}@example.com",
          photos: [ Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/wp_sample.png"), "image/png") ] }
      },
      model: "GalleryPhoto"
    },
    bee_hive: {
      limit: 10,
      action: -> { bee_hives_path },
      params: ->(i) { { bee_hive: { name: "Jane #{i}", email: "jane@example.com", address: "Ann Arbor, MI" } } },
      model: "BeeHive"
    },
    newsletter_subscriber: {
      limit: 5,
      action: -> { newsletter_subscribers_path },
      params: ->(i) { { email: "reader#{i}@example.com" } },
      model: "NewsletterSubscriber"
    },
    registration: {
      limit: 3,
      action: -> { user_registration_path },
      params: ->(i) { { user: { name: "Jane", email: "jane#{i}@example.com", password: "password123", password_confirmation: "password123" } } },
      model: "User"
    }
  }.freeze

  # In production, Railway's edge proxy (100.64.0.0/10) forwards to Thruster, which
  # appends that hop to X-Forwarded-For before passing the request to Puma on localhost.
  def submit(endpoint, i, client_ip:)
    post instance_exec(&endpoint[:action]),
      params: instance_exec(i, &endpoint[:params]),
      headers: { "X-Forwarded-For" => "#{client_ip}, #{RAILWAY_PROXY_IP}" }
    # Registration signs the new user in; sign out so the next attempt is anonymous again.
    delete destroy_user_session_path if endpoint[:model] == "User"
  end

  ENDPOINTS.each do |key, endpoint|
    test "#{key}: submissions beyond the limit from one visitor are rejected" do
      endpoint[:limit].times { |i| submit(endpoint, i, client_ip: "203.0.113.9") }

      assert_no_difference "#{endpoint[:model]}.count" do
        submit(endpoint, endpoint[:limit], client_ip: "203.0.113.9")
      end
      assert_match "submitting too quickly", flash[:alert]
    end

    test "#{key}: one visitor hitting the limit does not block another visitor behind the same proxy" do
      endpoint[:limit].times { |i| submit(endpoint, i, client_ip: "203.0.113.9") }

      assert_difference "#{endpoint[:model]}.count", 1 do
        submit(endpoint, endpoint[:limit], client_ip: "198.51.100.7")
      end
    end
  end

  test "a bot cannot dodge the limit by prepending fake addresses to X-Forwarded-For" do
    endpoint = ENDPOINTS[:newsletter_subscriber]
    (endpoint[:limit] + 1).times do |i|
      post newsletter_subscribers_path, params: { email: "reader#{i}@example.com" },
        headers: { "X-Forwarded-For" => "198.18.0.#{i}, 203.0.113.9, #{RAILWAY_PROXY_IP}" }
    end

    assert_equal endpoint[:limit], NewsletterSubscriber.where("email LIKE ?", "reader%").count
  end

  test "the limit resets after the window passes" do
    endpoint = ENDPOINTS[:newsletter_subscriber]
    endpoint[:limit].times { |i| submit(endpoint, i, client_ip: "203.0.113.9") }

    travel 11.minutes

    assert_difference "NewsletterSubscriber.count", 1 do
      submit(endpoint, endpoint[:limit], client_ip: "203.0.113.9")
    end
  end
end
