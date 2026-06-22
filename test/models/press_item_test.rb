require "test_helper"

class PressItemTest < ActiveSupport::TestCase
  test "all loads items from YAML" do
    items = PressItem.all
    assert items.size > 0
    assert_instance_of PressItem, items.first
  end

  test "each item has date, source, title, url, kind, snippet" do
    item = PressItem.all.first
    assert_respond_to item, :date
    assert_respond_to item, :source
    assert_respond_to item, :title
    assert_respond_to item, :url
    assert_respond_to item, :kind
    assert_respond_to item, :snippet
  end

  test "years returns descending unique years" do
    years = PressItem.years
    assert_equal years, years.uniq
    assert_equal years, years.sort.reverse
  end

  test "grouped_by_year groups items into year buckets, descending" do
    groups = PressItem.grouped_by_year
    years = groups.map(&:first)
    assert_equal years, years.sort_by { |y| -(y || 0) }
    groups.each { |year, items| assert items.all? { |i| i.year == year } }
  end
end
