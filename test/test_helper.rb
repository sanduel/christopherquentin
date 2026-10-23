ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

Geocoder.configure(lookup: :test, ip_lookup: :test)
Geocoder::Lookup::Test.set_default_stub(
  [ { "latitude" => 42.2808, "longitude" => -83.7430, "address" => "Ann Arbor, MI", "country" => "United States" } ]
)

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    fixtures :all

    setup { Rails.cache.clear }
  end
end

module AntiSpamHelper
  def honeypot_names_in(form_selector)
    names = []
    assert_select form_selector do
      assert_select "input" do |inputs|
        names = inputs.map { |input| input["name"] } & InvisibleCaptcha.honeypots
      end
    end
    names
  end

  def hidden_fields_in(form_selector)
    css_select("#{form_selector} input[type=hidden]")
      .select { |input| input["name"] }
      .to_h { |input| [ input["name"], input["value"] ] }
      .except("_method", "authenticity_token")
  end
end

module SignInHelper
  def sign_in_as(user)
    post user_session_path, params: {
      user: { email: user.email, password: "password123" }
    }
  end

  def sign_in_admin
    admin = User.create!(name: "Admin", email: "testadmin@test.com", password: "password123", role: :admin)
    sign_in_as(admin)
    admin
  end

  def sign_in_contributor
    user = User.create!(name: "Contributor", email: "contributor@test.com", password: "password123", role: :contributor)
    sign_in_as(user)
    user
  end
end
