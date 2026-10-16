require "test_helper"

class AntiSpamTest < ActionDispatch::IntegrationTest
  include AntiSpamHelper

  ENDPOINTS = {
    tribute: {
      form_page: -> { new_tribute_path },
      action: -> { tributes_path },
      params: ->(i) { { tribute: { name: "Jane #{i}", relationship: "Friend", content: "A light." } } },
      model: "Tribute"
    },
    memory: {
      form_page: -> { root_path },
      action: -> { memories_path },
      params: ->(i) { { memory: { date: "2010-05-01", content: "Memory #{i}", name: "Jane", email: "jane#{i}@example.com" } } },
      model: "Memory"
    },
    reply: {
      form_page: -> { memories_path },
      action: -> { memory_replies_path(memories(:hanover)) },
      params: ->(i) { { reply: { name: "Jane", email: "jane#{i}@example.com", body: "Reply #{i}" } } },
      model: "Reply"
    },
    tree_from_projects_page: {
      form_page: -> { projects_path },
      action: -> { trees_path },
      params: ->(i) { { tree: { name: "Jane #{i}", email: "jane@example.com", address: "Ann Arbor, MI", tree_count: 1 } } },
      model: "Tree"
    },
    tree_from_new_page: {
      form_page: -> { new_tree_path },
      action: -> { trees_path },
      params: ->(i) { { tree: { name: "Jane #{i}", email: "jane@example.com", address: "Ann Arbor, MI", tree_count: 1 } } },
      model: "Tree"
    },
    recipe: {
      form_page: -> { new_recipe_path },
      action: -> { recipes_path },
      params: ->(i) { { recipe: { submitter_name: "Jane", title: "Soup #{i}", ingredients: "Water", instructions: "Boil" } } },
      model: "Recipe"
    },
    gallery_photo: {
      form_page: -> { submit_photos_path },
      action: -> { submit_photos_path },
      params: ->(i) {
        { submitter_name: "Jane", submitter_email: "jane#{i}@example.com",
          photos: [ Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/wp_sample.png"), "image/png") ] }
      },
      model: "GalleryPhoto"
    },
    newsletter_subscriber: {
      form_page: -> { root_path },
      action: -> { newsletter_subscribers_path },
      params: ->(i) { { email: "reader#{i}@example.com" } },
      model: "NewsletterSubscriber"
    },
    bee_hive: {
      form_page: -> { new_bee_hive_path },
      action: -> { bee_hives_path },
      params: ->(i) { { bee_hive: { name: "Jane #{i}", email: "jane@example.com", address: "Ann Arbor, MI" } } },
      model: "BeeHive"
    },
    registration: {
      form_page: -> { new_user_registration_path },
      action: -> { user_registration_path },
      params: ->(i) { { user: { name: "Jane", email: "jane#{i}@example.com", password: "password123", password_confirmation: "password123" } } },
      model: "User"
    }
  }.freeze

  ENDPOINTS.each do |key, endpoint|
    test "#{key}: the form includes a honeypot field" do
      get instance_exec(&endpoint[:form_page])
      assert_response :success

      action = instance_exec(&endpoint[:action])
      assert_not_empty honeypot_names_in("form[action='#{action}']"),
        "expected the form posting to #{action} to render invisible_captcha"
    end

    test "#{key}: a submission with the honeypot filled in is rejected" do
      params = instance_exec(1, &endpoint[:params]).merge(InvisibleCaptcha.honeypots.first => "http://spam.example")

      assert_no_difference "#{endpoint[:model]}.count" do
        post instance_exec(&endpoint[:action]), params: params
      end
      assert_response :see_other
      assert_match "couldn't accept that submission", flash[:alert]
    end

    test "#{key}: a honeypot rendered before a restart is still caught after it" do
      get instance_exec(&endpoint[:form_page])
      honeypot = honeypot_names_in("form[action='#{instance_exec(&endpoint[:action])}']").first

      InvisibleCaptcha.instance_variable_set(:@honeypots, nil)
      load Rails.root.join("config/initializers/invisible_captcha.rb")

      assert_no_difference "#{endpoint[:model]}.count" do
        post instance_exec(&endpoint[:action]),
          params: instance_exec(1, &endpoint[:params]).merge(honeypot => "http://spam.example")
      end
    end

    test "#{key}: a real visitor gets through even after other pages load in between" do
      get instance_exec(&endpoint[:form_page])
      action = instance_exec(&endpoint[:action])
      hidden_fields = hidden_fields_in("form[action='#{action}']")
      # Turbo prefetches pages on link hover and visitors open other tabs; both render forms.
      travel 30.seconds
      get chris_path
      travel 1.second

      assert_difference "#{endpoint[:model]}.count", 1 do
        post action, params: hidden_fields.merge(instance_exec(1, &endpoint[:params]))
      end
    end
  end
end
