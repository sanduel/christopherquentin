require "test_helper"

class EventTest < ActiveSupport::TestCase
  test "valid with required attributes" do
    event = Event.new(
      title: "Memorial Concert",
      event_type: :concert,
      starts_at: 1.day.from_now
    )
    assert event.valid?
  end

  test "title is required" do
    event = Event.new(event_type: :concert, starts_at: 1.day.from_now)
    assert_not event.valid?
    assert_includes event.errors[:title], "can't be blank"
  end

  test "starts_at is required" do
    event = Event.new(title: "X", event_type: :webinar)
    assert_not event.valid?
    assert_includes event.errors[:starts_at], "can't be blank"
  end

  test "event_type is required" do
    event = Event.new(title: "X", starts_at: 1.day.from_now)
    assert_not event.valid?
    assert_includes event.errors[:event_type], "can't be blank"
  end

  test "ends_at must be after starts_at when present" do
    event = Event.new(
      title: "X",
      event_type: :concert,
      starts_at: 1.day.from_now,
      ends_at: 1.day.from_now - 1.hour
    )
    assert_not event.valid?
    assert_includes event.errors[:ends_at], "must be after the start time"
  end

  test "ends_at can be blank" do
    event = Event.new(
      title: "X",
      event_type: :concert,
      starts_at: 1.day.from_now,
      ends_at: nil
    )
    assert event.valid?
  end

  test "published scope returns only published events" do
    published = Event.create!(title: "P", event_type: :concert, starts_at: 1.day.from_now, published: true)
    Event.create!(title: "D", event_type: :concert, starts_at: 1.day.from_now, published: false)

    assert_equal [ published ], Event.published.to_a
  end

  test "upcoming scope returns events at or after now, ordered ascending" do
    later = Event.create!(title: "Later", event_type: :concert, starts_at: 5.days.from_now, published: true)
    sooner = Event.create!(title: "Sooner", event_type: :concert, starts_at: 1.day.from_now, published: true)
    Event.create!(title: "Past", event_type: :concert, starts_at: 1.day.ago, published: true)

    assert_equal [ sooner, later ], Event.upcoming.to_a
  end

  test "past scope returns events before now, ordered descending" do
    recent = Event.create!(title: "Recent", event_type: :concert, starts_at: 1.day.ago, published: true)
    older = Event.create!(title: "Older", event_type: :concert, starts_at: 30.days.ago, published: true)
    Event.create!(title: "Future", event_type: :concert, starts_at: 1.day.from_now, published: true)

    assert_equal [ recent, older ], Event.past.to_a
  end
end
