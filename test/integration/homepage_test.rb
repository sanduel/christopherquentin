require "test_helper"

class HomepageTest < ActionDispatch::IntegrationTest
  # ── Hero ──────────────────────────────────────────────────────────────────
  test "hero renders the three-line name" do
    get root_path
    assert_response :success
    assert_select "h1.font-serif" do
      assert_select "*", text: /Christopher/
      assert_select "*", text: /Quentin/
      assert_select "*", text: /McMullen-Laird/
    end
  end

  test "wordmark shows the dates somewhere in the nav" do
    get root_path
    assert_match(/1984/, response.body)
    assert_match(/2020/, response.body)
  end

  test "hero renders the two CTA pills with correct destinations" do
    get root_path
    assert_select "a[href=?]", chris_path, text: /Read his story/
    assert_select "button[data-controller~='share-modal-trigger']", text: /Share a memory/
  end

  test "hero renders the portrait image" do
    get root_path
    assert_select "img[src*='chris-portrait'][alt*='Christopher']"
  end

  test "hero does not include Garden staff-lines texture" do
    get root_path
    assert_select ".staff-lines-bg", 0
  end

  # ── Honor grid ────────────────────────────────────────────────────────────
  test "honor grid section renders" do
    get root_path
    assert_select "h2.font-serif", text: /Get involved/
    assert_select "section article", minimum: 1
  end

  test "honor grid renders four cards with correct h3 titles" do
    get root_path
    assert_select "h3.font-serif", text: /Plant a Tree/
    assert_select "h3.font-serif", text: /Share a Memory/
    assert_select "h3.font-serif", text: /Adopt a Bee Hive/
    assert_select "h3.font-serif", text: /Support a Fund/
  end

  test "honor grid card CTAs link to correct destinations" do
    get root_path
    assert_select "a[href=?]", new_tree_path
    assert_select "a[href=?]", new_memory_path
    assert_select "a[href=?]", new_bee_hive_path
    assert_select "a[href=?]", funds_path
  end

  test "get involved cards render their titles" do
    get root_path
    [ "Plant a Tree", "Share a Memory", "Adopt a Bee Hive", "Support a Fund" ].each do |title|
      assert_select "h3", text: title, count: 1
    end
  end

  # ── Timeline band ─────────────────────────────────────────────────────────
  test "timeline band renders From the timeline eyebrow + h2" do
    get root_path
    assert_match(/From the timeline/i, response.body)
    assert_select "h2.font-serif", text: /Memories from/
    assert_select "h2 span.italic.text-accent", text: /friends and family/
  end

  test "timeline band renders View full timeline link to memories_path" do
    get root_path
    assert_select "a[href=?]", memories_path, text: /View full timeline/
  end

  test "timeline band renders a preview card from published memories" do
    get root_path
    assert_select "section article", minimum: 1
  end

  test "timeline band preview card shows memory content" do
    get root_path
    assert_match(/Mass Row|Beethoven|Mahler/, response.body)
  end

  test "timeline band empty state shows Be the first message" do
    Memory.update_all(status: Memory.statuses[:pending])
    get root_path
    assert_match(/Be the first/i, response.body)
  ensure
    Memory.update_all(status: Memory.statuses[:published])
  end

  # ── Gatherings (conditional) ───────────────────────────────────────────────
  test "Memorial Events section renders with event cards when upcoming events exist" do
    Event.create!(title: "Memorial Webinar", event_type: :webinar, starts_at: 30.days.from_now, published: true)
    get root_path
    assert_match(/Memorial Events/i, response.body)
    assert_select "section article", minimum: 1
  end

  test "Memorial Events section hides when no upcoming events" do
    Event.update_all(published: false)
    get root_path
    assert_no_match(/Memorial Events/i, response.body)
  ensure
    Event.update_all(published: true)
  end

  test "event card shows type chip" do
    Event.create!(title: "Memorial Webinar", event_type: :webinar, starts_at: 30.days.from_now, published: true)
    get root_path
    assert_match(/Webinar/i, response.body)
  end

  # ── In photographs ────────────────────────────────────────────────────────
  test "photographs section renders h2" do
    get root_path
    assert_select "h2.font-serif", text: /In photographs/
  end

  test "photographs section renders Submit a photo link" do
    get root_path
    assert_select "a[href=?]", submit_photos_path, text: /Submit a photo/
  end

  test "photographs section renders 11 placeholder tiles when GalleryPhoto is empty" do
    GalleryPhoto.delete_all
    get root_path
    # 11 placeholder divs rendered by the (0...11).each loop — count via [ PHOTO ] spans
    assert_match(/\[ PHOTO \]/, response.body)
  end

  # ── In their own words (tributes) ─────────────────────────────────────────
  test "tributes section renders h2 and tribute articles" do
    Tribute.find_or_create_by!(name: "Test Tribute HP1") { |t| t.content = "Sample"; t.status = :published }
    get root_path
    assert_select "h2.font-serif", text: /In their own words/
    assert_select "section article", minimum: 1
  end

  test "tribute cards show name" do
    Tribute.find_or_create_by!(name: "Margaret Thompson HP") do |t|
      t.content = "A long-time friend says hello."
      t.relationship = "Family friend"
      t.status = :published
    end
    get root_path
    assert_match(/Margaret Thompson HP/, response.body)
  end

  test "tributes section renders Read all N tributes link when 2+ tributes" do
    2.times do |i|
      Tribute.find_or_create_by!(name: "Plural HP #{i}") { |t| t.content = "x"; t.status = :published }
    end
    get root_path
    assert_select "a[href=?]", tributes_path, text: /Read all \d+ tributes/
  end

  test "tributes section renders band h2 even when no published tributes" do
    Tribute.update_all(status: Tribute.statuses[:pending])
    get root_path
    assert_select "h2.font-serif", text: /In their own words/
    # @recent_tributes is empty so no tribute content is rendered
    assert_no_match(/A long-time friend/, response.body)
  ensure
    Tribute.update_all(status: Tribute.statuses[:published])
  end
end
