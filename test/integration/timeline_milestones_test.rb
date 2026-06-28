require "test_helper"

class TimelineMilestonesTest < ActionDispatch::IntegrationTest
  def setup
    Memory.delete_all
    Milestone.delete_all
    Memory.create!(date: Date.new(2014, 6, 15), content: "Munich concert",
                   name: "Colleague", email: "c@a.com", kind: :text, status: :published)
  end

  test "a milestone renders on the timeline under its year" do
    Milestone.create!(date: Date.new(2014, 3, 1), headline: "Joined the orchestra",
                      description: "A new chapter.")
    get memories_path
    assert_response :success
    assert_match "Joined the orchestra", response.body
    assert_match "A new chapter.", response.body
  end

  test "a milestone anchors a year that has no memories" do
    Milestone.create!(date: Date.new(1984, 1, 1), headline: "Born in Tokyo")
    get memories_path
    assert_match "Born in Tokyo", response.body
    # 1984 year marker appears even though no memory exists that year
    assert_match "1984", response.body
    assert_match "he was 0", response.body
  end

  test "milestones are excluded from the memory and contributor counts" do
    get memories_path
    baseline = response.body[/(\d+)\s+memor/, 1]

    Milestone.create!(date: Date.new(1984, 1, 1), headline: "Born in Tokyo")
    get memories_path
    after = response.body[/(\d+)\s+memor/, 1]

    assert_equal baseline, after, "adding a milestone must not change the memory count"
  end

  test "a milestone year appears as a year filter chip" do
    Milestone.create!(date: Date.new(1984, 1, 1), headline: "Born in Tokyo")
    get memories_path
    assert_select "[data-year-filter]" do
      assert_select "a, button", text: "1984"
    end
  end

  test "filtering by a milestone-only year shows the milestone" do
    Milestone.create!(date: Date.new(1984, 1, 1), headline: "Born in Tokyo")
    get memories_path, params: { year: 1984 }
    assert_match "Born in Tokyo", response.body
    assert_no_match "Munich concert", response.body
  end

  test "within a shared year memory and milestone both render" do
    Milestone.create!(date: Date.new(2014, 1, 1), headline: "Milestone in 2014")
    get memories_path, params: { year: 2014 }
    assert_match "Milestone in 2014", response.body
    assert_match "Munich concert", response.body
  end
end
