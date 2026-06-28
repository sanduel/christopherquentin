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
    assert_match(/Tributes.*voices/m, response.body)
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
    assert_select "[data-category-filter] .bg-ink.text-white-bg", text: "All"
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

  test "invalid category param does not raise — treats as no filter" do
    Tribute.delete_all
    Tribute.create!(name: "X", content: "y", category: :musicians, status: :published)

    get tributes_path, params: { category: "not_a_real_category" }

    assert_response :success
    assert_select "[data-category-filter] .bg-ink.text-white-bg", text: "All"
    assert_match "X", response.body
  end

  test "photo attachments are eager-loaded (no N+1 as tributes grow)" do
    Tribute.delete_all
    img = Rails.root.join("test/fixtures/files/wp_sample.png")
    attach = ->(t) { t.photo.attach(io: File.open(img), filename: "x.png", content_type: "image/png") }

    3.times { |i| attach.call(Tribute.create!(name: "A#{i}", content: "c", status: :published)) }
    baseline = count_queries { get tributes_path }

    5.times { |i| attach.call(Tribute.create!(name: "B#{i}", content: "c", status: :published)) }
    grown = count_queries { get tributes_path }

    assert_operator grown - baseline, :<, 5,
      "Query count grew #{baseline}->#{grown} after adding 5 tributes with photos — likely an N+1 on attachments."
  end

  private

  def count_queries
    count = 0
    sub = ActiveSupport::Notifications.subscribe("sql.active_record") do |_, _, _, _, payload|
      name = payload[:name].to_s
      count += 1 unless payload[:cached] || name =~ /SCHEMA|TRANSACTION/
    end
    yield
    count
  ensure
    ActiveSupport::Notifications.unsubscribe(sub)
  end
end
