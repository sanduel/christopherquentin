require "test_helper"

class TributesIndexTest < ActionDispatch::IntegrationTest
  def setup
    Tribute.delete_all
    Tribute.create!(name: "Mom", relationship: "Mother", content: "My dearest son.", category: :family, status: :published)
    Tribute.create!(name: "Colleague", content: "A genius in the pit.", category: :musicians, status: :published)
    Tribute.create!(name: "Student", content: "He changed my musical life.", category: :students, status: :published)
  end

  test "renders header" do
    get tributes_path
    assert_response :success
    assert_select ".text-eyebrow", text: /Op\. V · Tributes/
    assert_select "h1.font-serif", text: /In their/
  end

  test "renders category filter chips" do
    get tributes_path
    assert_select "[data-category-filter]" do
      assert_select "*", text: "All"
      assert_select "*", text: /Family/i
      assert_select "*", text: /Colleagues/i
      assert_select "*", text: /Musicians/i
      assert_select "*", text: /Students/i
      assert_select "*", text: /Friends/i
    end
  end

  test "all chip active by default" do
    get tributes_path
    assert_select "[data-category-filter] .bg-moss.text-cream", text: "All"
  end

  test "category filter selects only that category" do
    get tributes_path, params: { category: "musicians" }
    assert_match "A genius in the pit.", response.body
    assert_no_match "My dearest son.", response.body
    assert_no_match "He changed my musical life.", response.body
  end

  test "renders Share a tribute CTA" do
    get tributes_path
    assert_select "a[href=?]", new_tribute_path, text: /Share a tribute/i
  end

  test "empty category shows Clear filter link" do
    Tribute.where(category: :colleagues).delete_all
    get tributes_path, params: { category: "colleagues" }
    assert_match(/No tributes in this category/, response.body)
    assert_select "a[href=?]", tributes_path, text: /Clear filter/i
  end
end
