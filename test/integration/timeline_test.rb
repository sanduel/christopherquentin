require "test_helper"

class TimelineTest < ActionDispatch::IntegrationTest
  def setup
    Memory.delete_all
    Memory.create!(date: Date.new(2002, 9, 1), content: "Mass Row", location: "Hanover, NH",
                   name: "Friend", email: "f@a.com", kind: :text, status: :published)
    Memory.create!(date: Date.new(2014, 6, 15), content: "Munich concert", location: "Munich, Germany",
                   name: "Colleague", email: "c@a.com", kind: :text, status: :published)
    Memory.create!(date: Date.new(2019, 5, 12), content: "Stavanger rehearsal", location: "Stavanger, Norway",
                   name: "Student", email: "s@a.com", kind: :text, status: :published)
  end

  test "timeline renders the header with eyebrow + h1" do
    get memories_path
    assert_response :success
    assert_select ".text-eyebrow", text: /Op\. III · The Timeline/
    assert_select "h1.font-serif", text: /A life, kept by/
  end

  test "timeline renders the Share a memory CTA" do
    get memories_path
    assert_select "button, a", text: /Share a memory/i
  end

  test "timeline renders year filter chips for each unique year" do
    get memories_path
    assert_select "[data-year-filter]" do
      assert_select "a, button", text: "All"
      assert_select "a, button", text: "2002"
      assert_select "a, button", text: "2014"
      assert_select "a, button", text: "2019"
    end
  end

  test "All chip is active when no year filter" do
    get memories_path
    assert_select "[data-year-filter] .bg-moss.text-cream", text: "All"
  end

  test "Year chip is active when filtered" do
    get memories_path, params: { year: 2014 }
    assert_select "[data-year-filter] .bg-moss.text-cream", text: "2014"
  end

  test "filtering by year renders only that year's memories" do
    get memories_path, params: { year: 2014 }
    assert_match "Munich concert", response.body
    assert_no_match "Mass Row", response.body
    assert_no_match "Stavanger rehearsal", response.body
  end

  test "year markers render he-was-N subtext" do
    get memories_path
    assert_match "he was 18", response.body
    assert_match "he was 30", response.body
    assert_match "he was 35", response.body
  end

  test "memory cards render content, name, location" do
    get memories_path
    assert_match "Mass Row", response.body
    assert_match "Hanover, NH", response.body
    assert_match "Friend", response.body
  end

  test "empty year filter shows Clear filter link" do
    get memories_path, params: { year: 2099 }
    assert_match(/No memories for 2099/, response.body)
    assert_select "a[href=?]", memories_path, text: /Clear filter/i
  end
end
