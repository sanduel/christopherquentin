require "test_helper"

class MilestoneTest < ActiveSupport::TestCase
  test "valid with date and headline" do
    milestone = Milestone.new(date: Date.new(1984, 1, 1), headline: "Born in Tokyo")
    assert milestone.valid?, milestone.errors.full_messages.inspect
  end

  test "invalid without date" do
    milestone = Milestone.new(headline: "Born in Tokyo")
    assert_not milestone.valid?
    assert_includes milestone.errors[:date], "can't be blank"
  end

  test "invalid without headline" do
    milestone = Milestone.new(date: Date.new(1984, 1, 1))
    assert_not milestone.valid?
    assert_includes milestone.errors[:headline], "can't be blank"
  end

  test "description, icon, location are optional" do
    milestone = Milestone.new(date: Date.new(1984, 1, 1), headline: "Born")
    assert milestone.valid?
    assert_nil milestone.description
    assert_nil milestone.icon
    assert_nil milestone.location
  end

  test "year is derived from date" do
    milestone = Milestone.new(date: Date.new(2002, 9, 1), headline: "Dartmouth")
    assert_equal 2002, milestone.year
  end

  test "age is year minus 1984" do
    milestone = Milestone.new(date: Date.new(2002, 9, 1), headline: "Dartmouth")
    assert_equal 18, milestone.age
  end

  test "chronological scope orders by date ascending" do
    later   = Milestone.create!(date: Date.new(2019, 5, 1), headline: "Stavanger")
    earlier = Milestone.create!(date: Date.new(1984, 1, 1), headline: "Born")
    assert_equal [ earlier, later ], Milestone.chronological.to_a
  end
end
