require "test_helper"

class ReplyTest < ActiveSupport::TestCase
  def setup
    @memory = Memory.create!(
      date: Date.today, content: "x",
      name: "Author", email: "author@test.com", status: :published
    )
  end

  test "valid reply with name + body + email (anonymous)" do
    reply = @memory.replies.build(name: "Alex", body: "Beautiful.", email: "alex@test.com")
    assert reply.valid?, reply.errors.full_messages.inspect
    assert_equal "pending", reply.status
  end

  test "invalid without name" do
    reply = @memory.replies.build(body: "x", email: "a@b.com")
    assert_not reply.valid?
    assert_includes reply.errors[:name], "can't be blank"
  end

  test "invalid without body" do
    reply = @memory.replies.build(name: "Alex", email: "a@b.com")
    assert_not reply.valid?
    assert_includes reply.errors[:body], "can't be blank"
  end

  test "anonymous reply requires email" do
    reply = @memory.replies.build(name: "Alex", body: "x")
    assert_not reply.valid?
    assert_includes reply.errors[:email], "can't be blank"
  end

  test "signed-in reply doesn't require email" do
    user = User.create!(name: "U", email: "u@test.com", password: "password123")
    reply = @memory.replies.build(name: "Alex", body: "x", user: user)
    assert reply.valid?
  end

  test "published scope filters status" do
    @memory.replies.create!(name: "A", email: "a@b.com", body: "x", status: :pending)
    @memory.replies.create!(name: "B", email: "b@c.com", body: "y", status: :published)
    assert_equal 1, Reply.published.count
  end
end
