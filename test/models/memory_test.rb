require "test_helper"

class MemoryTest < ActiveSupport::TestCase
  test "valid memory with date and content" do
    memory = Memory.new(date: Date.today, content: "A great day.")
    assert memory.valid?
    assert_equal "pending", memory.status
  end

  test "invalid without date" do
    memory = Memory.new(content: "A great day.")
    assert_not memory.valid?
    assert_includes memory.errors[:date], "can't be blank"
  end

  test "user is optional" do
    memory = Memory.new(date: Date.today, content: "A story.")
    assert memory.valid?
    assert_nil memory.user
  end
end
