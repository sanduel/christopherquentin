require "test_helper"

class SiteLayoutTest < ActionDispatch::IntegrationTest
  test "layout uses white-bg background and ink text" do
    get root_path
    assert_response :success
    assert_select "body.bg-white-bg.text-ink.font-sans"
  end

  test "layout includes Google Fonts for Newsreader, Hanken Grotesk, IBM Plex Mono" do
    get root_path
    assert_select "link[rel='stylesheet'][href*='fonts.googleapis.com']" do |links|
      hrefs = links.map { |l| l["href"] }
      assert hrefs.any? { |h| h.include?("Newsreader") }, "Expected Newsreader font"
      assert hrefs.any? { |h| h.include?("Hanken+Grotesk") }, "Expected Hanken Grotesk font"
      assert hrefs.any? { |h| h.include?("IBM+Plex+Mono") }, "Expected IBM Plex Mono font"
    end
  end

  test "layout does NOT load Josefin Sans" do
    get root_path
    assert_select "link[rel='stylesheet'][href*='Josefin']", 0
  end

  test "home_nav renders with wordmark and Share a memory CTA" do
    get root_path
    assert_select "nav[data-controller='nav']" do
      assert_select "span", /Christopher Quentin/
      assert_select "button[data-controller~='share-modal-trigger']", text: /Share a memory/
    end
  end

  test "home_nav shows Sign in for signed-out users" do
    get root_path
    assert_select "nav a[href=?]", new_user_session_path, /Sign in/
  end

  test "home_nav shows Sign out for signed-in users" do
    user = User.create!(name: "Test", email: "test-layout@test.com", password: "password123", role: :contributor)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
    get root_path

    assert_select "nav a", text: /Sign out/
  end

  test "footer renders newsletter form pointing at newsletter_subscribers_path" do
    get root_path
    assert_select "footer form[action=?]", newsletter_subscribers_path do
      assert_select "input[type='email'][name='email']"
      assert_select "input[type='submit'][value='Subscribe']"
    end
  end

  test "footer renders all three column titles" do
    get root_path
    assert_select "footer" do
      assert_select "div", text: "Christopher"
      assert_select "div", text: "Honor"
      assert_select "div", text: "More"
    end
  end

  test "footer renders copyright line with years" do
    get root_path
    assert_select "footer", text: /1984/
    assert_select "footer", text: /2020/
  end

  test "layout removes old utility bar dark-stone top strip" do
    get root_path
    # The old layout had a bg-stone-800 utility bar as the first element in <body>,
    # before the nav. Verify it is gone by checking the nav comes first and has no
    # bg-stone-800 class itself.
    assert_select "body > nav[data-controller='nav']"
    assert_select "body > nav.bg-stone-800", 0
    assert_select "body > div.bg-stone-800", 0
  end
end
