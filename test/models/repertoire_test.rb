require "test_helper"

class RepertoireTest < ActiveSupport::TestCase
  test "conducted returns an array of works grouped by composer" do
    list = Repertoire.conducted
    assert list.size > 0
    assert_respond_to list.first, :composer
    assert_respond_to list.first, :works
    assert_kind_of Array, list.first.works
  end

  test "assisted returns an array of works grouped by composer" do
    list = Repertoire.assisted
    assert list.size > 0
    assert_respond_to list.first, :composer
    assert_respond_to list.first, :works
  end
end
