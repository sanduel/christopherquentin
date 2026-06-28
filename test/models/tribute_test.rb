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

  test "invalid without content or video" do
    tribute = Tribute.new(name: "Jane")
    assert_not tribute.valid?
    assert_includes tribute.errors[:base], "Add a written tribute or a YouTube video."
  end

  test "valid with a YouTube video and no written content" do
    tribute = Tribute.new(name: "Jane", video_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    assert tribute.valid?
  end

  test "extracts youtube id from common url shapes" do
    %w[
      https://www.youtube.com/watch?v=dQw4w9WgXcQ
      https://youtu.be/dQw4w9WgXcQ
      https://www.youtube.com/embed/dQw4w9WgXcQ
      https://www.youtube.com/shorts/dQw4w9WgXcQ
      https://www.youtube.com/live/dQw4w9WgXcQ
      https://m.youtube.com/watch?v=dQw4w9WgXcQ
      youtube.com/watch?v=dQw4w9WgXcQ
    ].each do |url|
      assert_equal "dQw4w9WgXcQ", Tribute.new(video_url: url).youtube_id, url
    end
  end

  test "invalid with a non-youtube video url" do
    tribute = Tribute.new(name: "Jane", video_url: "https://vimeo.com/12345")
    assert_not tribute.valid?
    assert_includes tribute.errors[:video_url], "must be a valid YouTube link"
  end

  test "rejects a non-youtube host that mimics a youtube path" do
    tribute = Tribute.new(name: "Jane", video_url: "https://evil.com/embed/dQw4w9WgXcQ")
    assert_nil tribute.youtube_id
    assert_not tribute.valid?
  end

  test "does not raise on urls with no path" do
    tribute = Tribute.new(name: "Jane", video_url: "mailto:someone@example.com")
    assert_nothing_raised { tribute.valid? }
    assert_nil tribute.youtube_id
    assert_not tribute.valid?
  end

  test "normalizes a valid youtube url to a canonical watch url" do
    tribute = Tribute.create!(name: "Jane", video_url: "https://youtu.be/dQw4w9WgXcQ")
    assert_equal "https://www.youtube.com/watch?v=dQw4w9WgXcQ", tribute.video_url
  end

  test "published scope returns only published tributes" do
    Tribute.create!(name: "Published", content: "Content", status: :published)
    Tribute.create!(name: "Pending", content: "Content", status: :pending)
    Tribute.create!(name: "Rejected", content: "Content", status: :rejected)

    assert_equal 1, Tribute.published.count
    assert_equal "Published", Tribute.published.first.name
  end

  test "default category is friends" do
    t = Tribute.new(name: "X", content: "y")
    assert_equal "friends", t.category
  end

  test "category enum supports family/colleagues/musicians/students/friends" do
    t = Tribute.new(name: "X", content: "y")
    %w[family colleagues musicians students friends].each do |cat|
      t.category = cat
      assert_equal cat, t.category
    end
  end

  test "category predicates use prefix" do
    t = Tribute.new(name: "X", content: "y", category: :musicians)
    assert t.category_musicians?
    assert_not t.category_family?
  end
end
