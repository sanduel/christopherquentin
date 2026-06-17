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
end
