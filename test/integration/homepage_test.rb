require "test_helper"

class HomepageTest < ActionDispatch::IntegrationTest
  test "hero renders the three-line name with italic Quentin in moss" do
    get root_path
    assert_response :success
    assert_select "h1.font-serif" do
      assert_select "*", text: /Christopher/
      assert_select "span.font-serif.italic.text-moss", text: "Quentin"
      assert_select "*", text: /McMullen-Laird/
    end
  end

  test "hero renders the Op. 1984 eyebrow with sage rule" do
    get root_path
    assert_select ".text-eyebrow", text: /Op\. 1984.+In Memoriam/
    assert_select "span.bg-sage", minimum: 1
  end

  test "hero renders the tagline" do
    get root_path
    assert_select ".font-serif.italic", text: /Conductor.+environmentalist.+beloved/i
  end

  test "hero renders the Jaerbladet press blockquote with rose left border" do
    get root_path
    assert_select "blockquote" do
      assert_select "p", text: /scintillating charisma/
      assert_select "footer", text: /Jærbladet/
    end
  end

  test "hero renders the two CTA pills with correct destinations" do
    get root_path
    assert_select "a[href=?]", chris_path, text: /Read his story/
    assert_select "a[href=?]", new_memory_path, text: /Share a memory/
  end

  test "hero renders portrait placeholder with caption" do
    get root_path
    assert_match %r{\[ portrait — Stavanger 2019 \]}, response.body
  end

  test "hero includes faint staff_lines texture" do
    get root_path
    assert_select "[data-section='hero'] .staff-lines-bg"
  end

  test "MVT I renders movement label with andante con moto marking" do
    get root_path
    assert_select "[data-section='honor-grid'] .text-eyebrow", text: /MVT\. I/
    assert_select "[data-section='honor-grid'] h2", text: /Honor his memory/
    assert_select "[data-section='honor-grid'] span", text: /andante con moto/
  end

  test "MVT I renders four honor cards with correct destinations and titles" do
    get root_path
    [
      [new_tree_path,     "Plant a Tree"],
      [new_memory_path,   "Share a Memory"],
      [new_bee_hive_path, "Adopt a Bee Hive"],
      [funds_path,        "Support a Fund"],
    ].each do |path, title|
      assert_select "[data-section='honor-grid'] a[href=?]", path do
        assert_select "h3", text: title
      end
    end
  end

  test "MVT I cards each render a musical glyph" do
    get root_path
    body = response.body
    %w[❦ ¶ ♪ ♭].each do |glyph|
      assert_match Regexp.new(Regexp.escape(glyph)), body, "Expected glyph #{glyph} in honor grid"
    end
  end

  test "MVT II renders movement label with from-the-timeline eyebrow" do
    get root_path
    assert_select "[data-section='timeline-preview'] .text-eyebrow", text: /MVT\. II/
    assert_select "[data-section='timeline-preview'] h2", text: /A life, kept by/
    assert_select "[data-section='timeline-preview'] h2 em.text-moss", text: /many hands/
  end

  test "MVT II renders View full timeline pill linking to memories_path" do
    get root_path
    assert_select "[data-section='timeline-preview'] a[href=?]", memories_path, text: /View full timeline/
  end

  test "MVT II renders up to 3 preview cards from published memories" do
    get root_path
    assert_select "[data-section='timeline-preview'] article", minimum: 1
    assert_select "[data-section='timeline-preview'] article", maximum: 3
  end

  test "MVT II preview card shows memory location, body" do
    get root_path
    assert_select "[data-section='timeline-preview']" do
      assert_select ".text-eyebrow", text: /Hanover|Munich|Stavanger/
      assert_select "p", text: /Mass Row|Beethoven|Mahler/
    end
  end

  test "MVT II empty state — shows Be the first card when no memories" do
    Memory.update_all(status: Memory.statuses[:pending])
    get root_path
    assert_select "[data-section='timeline-preview'] a[href=?]", new_memory_path, text: /Be the first/
  ensure
    Memory.update_all(status: Memory.statuses[:published])
  end

  test "MVT III renders movement label with vivace marking" do
    Event.create!(title: "Memorial Webinar", event_type: :webinar, starts_at: 30.days.from_now, published: true)
    get root_path
    assert_select "[data-section='events-preview'] .text-eyebrow", text: /MVT\. III/
    assert_select "[data-section='events-preview'] h2", text: /Upcoming gatherings/
    assert_select "[data-section='events-preview'] span", text: /vivace/
  end

  test "MVT III renders one event card per upcoming event" do
    Event.create!(title: "Memorial Webinar", event_type: :webinar, starts_at: 30.days.from_now, published: true)
    get root_path
    assert_select "[data-section='events-preview'] article", minimum: 1, maximum: 3
  end

  test "MVT III event card shows category chip" do
    Event.create!(title: "Memorial Webinar", event_type: :webinar, starts_at: 30.days.from_now, published: true)
    get root_path
    assert_select "[data-section='events-preview'] article" do
      assert_select "span.bg-linen.text-moss", text: /Webinar|Concert|Service/i
    end
  end

  test "MVT III hides article cards when no upcoming events" do
    Event.update_all(published: false)
    get root_path
    assert_select "[data-section='events-preview'] article", 0
  ensure
    Event.update_all(published: true)
  end

  test "MVT IV renders movement label with lento e sereno marking" do
    get root_path
    assert_select "[data-section='gallery-preview'] .text-eyebrow", text: /MVT\. IV/
    assert_select "[data-section='gallery-preview'] h2", text: /In photographs/
    assert_select "[data-section='gallery-preview'] span", text: /lento e sereno/
  end

  test "MVT IV renders Submit a photo link" do
    get root_path
    assert_select "[data-section='gallery-preview'] a[href=?]", new_photo_submission_path, text: /Submit a photo/
  end

  test "MVT IV renders 6 placeholder gradient blocks when GalleryPhoto is empty" do
    GalleryPhoto.delete_all
    get root_path
    assert_select "[data-section='gallery-preview'] [data-gallery-tile]", count: 6
  ensure
    # No-op restore (we don't reseed gallery photos within a transactional test).
    # Pattern parity with peer tests.
  end

  test "MVT V renders movement label with cantabile marking" do
    Tribute.find_or_create_by!(name: "Test Tribute MVTV1") { |t| t.content = "Sample"; t.status = :published }
    get root_path
    assert_select "[data-section='tributes-preview'] .text-eyebrow", text: /MVT\. V/
    assert_select "[data-section='tributes-preview'] h2", text: /In their own words/
    assert_select "[data-section='tributes-preview'] span", text: /cantabile/
  end

  test "MVT V renders up to 3 tribute quote cards" do
    3.times do |i|
      Tribute.find_or_create_by!(name: "Test Tribute MVTV-#{i}") do |t|
        t.content = "Sample tribute #{i}"
        t.status = :published
      end
    end
    get root_path
    assert_select "[data-section='tributes-preview'] blockquote", minimum: 1, maximum: 3
  end

  test "MVT V cards show name" do
    Tribute.find_or_create_by!(name: "Margaret Thompson MVTV") do |t|
      t.content = "A long-time friend says hello."
      t.relationship = "Family friend"
      t.status = :published
    end
    get root_path
    assert_select "[data-section='tributes-preview'] blockquote", text: /Margaret Thompson MVTV/
  end

  test "MVT V renders pluralized Read all N tributes link when 2+ tributes" do
    2.times do |i|
      Tribute.find_or_create_by!(name: "Plural Test #{i}") { |t| t.content = "x"; t.status = :published }
    end
    get root_path
    assert_select "[data-section='tributes-preview'] a[href=?]", tributes_path, text: /Read all \d+ tributes/
  end

  test "MVT V hides section when no tributes" do
    Tribute.update_all(status: Tribute.statuses[:pending])
    get root_path
    assert_select "[data-section='tributes-preview'] blockquote", 0
  ensure
    Tribute.update_all(status: Tribute.statuses[:published])
  end
end
