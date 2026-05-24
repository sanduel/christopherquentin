require "test_helper"

class TreeTest < ActiveSupport::TestCase
  test "valid tree with required fields" do
    tree = Tree.new(name: "Jane", address: "Ann Arbor, MI", tree_count: 1, latitude: 42.28, longitude: -83.74)
    assert tree.valid?
  end

  test "invalid without name" do
    tree = Tree.new(address: "Ann Arbor, MI")
    assert_not tree.valid?
    assert_includes tree.errors[:name], "can't be blank"
  end

  test "invalid without address" do
    tree = Tree.new(name: "Jane")
    assert_not tree.valid?
    assert_includes tree.errors[:address], "can't be blank"
  end

  test "tree_count must be positive" do
    tree = Tree.new(name: "Jane", address: "Ann Arbor, MI", tree_count: 0)
    assert_not tree.valid?
  end

  test "skips geocoding when lat/lng already set" do
    tree = Tree.new(name: "Jane", address: "Ann Arbor, MI", latitude: 42.28, longitude: -83.74, tree_count: 1)
    assert tree.valid?
  end
end
