require "test_helper"

class MemoryTest < ActiveSupport::TestCase
  test "valid text memory with date and content" do
    memory = Memory.new(date: Date.today, content: "A great day.", name: "Alex", email: "alex@example.com")
    assert memory.valid?, memory.errors.full_messages.inspect
    assert_equal "pending", memory.status
    assert_equal "text", memory.kind
  end

  test "valid with a YouTube video and no written content" do
    memory = Memory.new(date: Date.today, name: "Alex", email: "alex@example.com",
                        video_url: "https://youtu.be/dQw4w9WgXcQ")
    assert memory.valid?, memory.errors.full_messages.inspect
    assert memory.video?
    assert_equal "https://www.youtube.com/watch?v=dQw4w9WgXcQ", memory.video_url
    assert_equal "https://www.youtube.com/embed/dQw4w9WgXcQ?rel=0", memory.youtube_embed_url
  end

  test "invalid with a non-YouTube video url" do
    memory = Memory.new(date: Date.today, content: "x", name: "Alex", email: "alex@example.com",
                        video_url: "https://vimeo.com/12345")
    assert_not memory.valid?
    assert_includes memory.errors[:video_url], "must be a valid YouTube link"
  end

  test "still invalid with neither content nor video" do
    memory = Memory.new(date: Date.today, name: "Alex", email: "alex@example.com")
    assert_not memory.valid?
    assert_includes memory.errors[:content], "can't be blank"
  end

  test "invalid without date" do
    memory = Memory.new(content: "A great day.", name: "Alex", email: "alex@example.com")
    assert_not memory.valid?
    assert_includes memory.errors[:date], "can't be blank"
  end

  test "user is optional" do
    memory = Memory.new(date: Date.today, content: "A story.", name: "Anonymous", email: "x@y.com")
    assert memory.valid?
    assert_nil memory.user
  end

  test "anonymous memory requires name" do
    memory = Memory.new(date: Date.today, content: "x", email: "x@y.com")
    assert_not memory.valid?
    assert_includes memory.errors[:name], "can't be blank"
  end

  test "anonymous memory requires email" do
    memory = Memory.new(date: Date.today, content: "x", name: "Alex")
    assert_not memory.valid?
    assert_includes memory.errors[:email], "can't be blank"
  end

  test "anonymous memory rejects malformed email" do
    memory = Memory.new(date: Date.today, content: "x", name: "Alex", email: "not-an-email")
    assert_not memory.valid?
    assert_includes memory.errors[:email].join, "invalid"
  end

  test "signed-in memory doesn't require name or email" do
    user = User.create!(name: "Sam", email: "sam@test.com", password: "password123")
    memory = Memory.new(date: Date.today, content: "x", user: user)
    assert memory.valid?, memory.errors.full_messages.inspect
  end

  test "kind enum predicates" do
    m = Memory.new(date: Date.today, content: "x", name: "A", email: "a@b.com")
    assert m.kind_text?
    m.kind = :photo
    assert m.kind_photo?
    m.kind = :audio
    assert m.kind_audio?
  end

  test "photo kind requires attached photos" do
    memory = Memory.new(date: Date.today, kind: :photo, name: "Alex", email: "a@b.com")
    assert_not memory.valid?
    assert_includes memory.errors[:photos], "is required for photo memories"
  end

  test "audio kind requires attached audio_clip" do
    memory = Memory.new(date: Date.today, kind: :audio, name: "Alex", email: "a@b.com")
    assert_not memory.valid?
    assert_includes memory.errors[:audio_clip], "is required for audio memories"
  end

  test "year is derived from date" do
    memory = Memory.new(date: Date.new(2014, 6, 15), content: "x", name: "A", email: "a@b.com")
    assert_equal 2014, memory.year
  end

  test "age is year minus 1984" do
    memory = Memory.new(date: Date.new(2014, 6, 15), content: "x", name: "A", email: "a@b.com")
    assert_equal 30, memory.age
  end

  test "display_name prefers memory.name over user.name" do
    user = User.create!(name: "Account Name", email: "u@test.com", password: "password123")
    memory = Memory.new(date: Date.today, content: "x", user: user, name: "Submitted Name")
    assert_equal "Submitted Name", memory.display_name
  end

  test "display_name falls back to user.name when memory.name is blank" do
    user = User.create!(name: "Account Name", email: "u@test.com", password: "password123")
    memory = Memory.new(date: Date.today, content: "x", user: user)
    assert_equal "Account Name", memory.display_name
  end

  test "display_name falls back to Anonymous when neither set" do
    memory = Memory.new(date: Date.today, content: "x")
    assert_equal "Anonymous", memory.display_name
  end

  test "default pin color is rose (distinct from tree green on map)" do
    assert_equal "#e11d48", Memory.default_pin_color
  end

  test "memory has many replies" do
    memory = Memory.create!(date: Date.today, content: "x", name: "A", email: "a@b.com", status: :published)
    reply = memory.replies.create!(name: "B", email: "b@c.com", body: "Yes!", status: :published)
    assert_equal [ reply ], memory.replies.to_a
  end
end
