require "test_helper"

class BeeHiveTest < ActiveSupport::TestCase
  test "valid with required attributes" do
    hive = BeeHive.new(name: "Garden hive", address: "Ann Arbor, MI")
    assert hive.valid?
  end

  test "name and address are required" do
    hive = BeeHive.new
    assert_not hive.valid?
    assert_includes hive.errors[:name], "can't be blank"
    assert_includes hive.errors[:address], "can't be blank"
  end

  test "geocodes from address" do
    hive = BeeHive.create!(name: "Garden hive", address: "Ann Arbor, MI")
    assert_equal 42.2808, hive.latitude
    assert_equal(-83.7430, hive.longitude)
  end

  test "default pin color and icon when not overridden" do
    hive = BeeHive.create!(name: "Garden hive", address: "Ann Arbor, MI")
    assert_equal BeeHive.default_pin_color, hive.effective_pin_color
    assert_equal BeeHive.default_pin_icon, hive.effective_pin_icon
  end

  test "overrides pin color and icon when set" do
    hive = BeeHive.create!(name: "Garden hive", address: "Ann Arbor, MI", pin_color: "#ff0000", pin_icon: "fire")
    assert_equal "#ff0000", hive.effective_pin_color
    assert_equal "fire", hive.effective_pin_icon
  end

  test "mapped scope returns hives with coordinates" do
    located = BeeHive.create!(name: "A", address: "Ann Arbor, MI")
    other = BeeHive.create!(name: "B", address: "X")
    other.update_columns(latitude: nil, longitude: nil)
    assert_includes BeeHive.mapped, located
    assert_not_includes BeeHive.mapped, other
  end
end
