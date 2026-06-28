require "test_helper"

class PublicPagesTest < ActionDispatch::IntegrationTest
  test "home page loads" do
    get root_path
    assert_response :success
    assert_select "h1", /Christopher Quentin/
  end

  test "home page shows action library with tree, memory, bee hive, and fund CTAs" do
    get root_path
    assert_response :success
    assert_select "a[href=?]", new_tree_path
    assert_select "a[href=?]", new_memory_path
    assert_select "a[href=?]", new_bee_hive_path
    assert_select "a[href=?]", funds_path
  end

  test "chris page loads" do
    get chris_path
    assert_response :success
    assert_select "h1", /McMullen-Laird/
  end

  test "bio redirects to chris" do
    get "/bio"
    assert_redirected_to "/chris"
  end

  test "projects page loads" do
    get projects_path
    assert_response :success
    assert_select "h1.font-serif", /Work in .*memory/i
  end

  test "funds redirects to projects#funds" do
    get funds_path
    assert_redirected_to "/projects#funds"
  end

  test "news page loads" do
    get news_path
    assert_response :success
    assert_select "h1.font-serif", /world's/i
  end

  test "zero waste page loads" do
    get zero_waste_path
    assert_response :success
    assert_select "h1.font-serif", /Zero Waste Week/
  end

  test "tributes page loads" do
    get tributes_path
    assert_response :success
    assert_select "h1.font-serif", /In their/
  end

  test "timeline page loads" do
    get memories_path
    assert_response :success
    assert_select "h1.font-serif", /A life, kept by/
  end

  test "trees redirects to projects#trees" do
    get trees_path
    assert_redirected_to "/projects#trees"
  end

  test "recipes page loads" do
    get recipes_path
    assert_response :success
    assert_select "h1.font-serif", /cooked/i
  end

  test "events index loads" do
    get events_path
    assert_response :success
    assert_select "h1.font-serif", /gathered/i
  end

  test "events index shows published upcoming events and excludes drafts" do
    published = Event.create!(title: "Spring Concert", event_type: :concert, starts_at: 7.days.from_now, published: true)
    Event.create!(title: "Draft Event", event_type: :concert, starts_at: 7.days.from_now, published: false)

    get events_path
    assert_response :success
    assert_select "a[href=?]", event_path(published), text: /Spring Concert/
    assert_select "a", text: /Draft Event/, count: 0
  end

  test "events show works for published" do
    event = Event.create!(title: "Tribute Concert", event_type: :concert, starts_at: 1.day.from_now, published: true)
    get event_path(event)
    assert_response :success
    assert_select "h1", /Tribute Concert/
  end

  test "events show 404s for unpublished" do
    event = Event.create!(title: "Hidden", event_type: :concert, starts_at: 1.day.from_now, published: false)
    get event_path(event)
    assert_response :not_found
  end

  test "home page surfaces upcoming events when present" do
    Event.create!(title: "Memorial Webinar", event_type: :webinar, starts_at: 5.days.from_now, published: true)
    get root_path
    assert_response :success
    assert_match(/Memorial Events/i, response.body)
    assert_match(/Memorial Webinar/, response.body)
  end

  test "home page hides upcoming events section when none" do
    Event.update_all(published: false)
    get root_path
    assert_response :success
    assert_no_match(/Upcoming gatherings/i, response.body)
  ensure
    Event.update_all(published: true)
  end

  test "bee hives index loads" do
    get bee_hives_path
    assert_response :success
    assert_select "h1.font-serif", /pollinators/i
  end

  test "bee hives new form loads" do
    get new_bee_hive_path
    assert_response :success
    assert_select "h1.font-serif", /bee hive/i
  end

  test "bee hive submission creates a pending hive" do
    assert_difference -> { BeeHive.count }, 1 do
      post bee_hives_path, params: {
        bee_hive: { name: "Backyard hive", address: "Ann Arbor, MI", story: "First swarm." }
      }
    end
    assert_redirected_to bee_hives_path
    hive = BeeHive.last
    assert hive.pending?
    assert_equal 42.2808, hive.latitude
  end

  test "map page loads" do
    get map_path
    assert_response :success
    assert_select "h1.font-serif", /left his mark/i
    assert_select "[data-controller=?]", "unified-map"
  end

  test "map renders pins for published mappable records" do
    Tree.create!(name: "Cabin tree", address: "Ann Arbor, MI", status: :published, tree_count: 1)
    BeeHive.create!(name: "Garden hive", address: "Ann Arbor, MI", status: :published)
    Event.create!(title: "Concert", event_type: :concert, starts_at: 1.day.from_now, location: "Ann Arbor, MI", published: true)

    get map_path
    assert_response :success
    pins_value = css_select("[data-controller=unified-map]").first["data-unified-map-pins-value"]
    pins = JSON.parse(pins_value)
    categories = pins.map { |p| p["category"] }.uniq.sort
    assert_equal [ "bee_hive", "event", "tree" ], categories
  end
end
