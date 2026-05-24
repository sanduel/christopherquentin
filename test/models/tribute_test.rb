require "test_helper"

class TributeTest < ActiveSupport::TestCase
  test "valid tribute with required fields" do
    tribute = Tribute.new(name: "Jane", content: "A wonderful person.")
    assert tribute.valid?
    assert_equal "pending", tribute.status
  end

  test "invalid without name" do
    tribute = Tribute.new(content: "A wonderful person.")
    assert_not tribute.valid?
    assert_includes tribute.errors[:name], "can't be blank"
  end

  test "invalid without content" do
    tribute = Tribute.new(name: "Jane")
    assert_not tribute.valid?
    assert_includes tribute.errors[:content], "can't be blank"
  end

  test "published scope returns only published tributes" do
    Tribute.create!(name: "Published", content: "Content", status: :published)
    Tribute.create!(name: "Pending", content: "Content", status: :pending)
    Tribute.create!(name: "Rejected", content: "Content", status: :rejected)

    assert_equal 1, Tribute.published.count
    assert_equal "Published", Tribute.published.first.name
  end
end
