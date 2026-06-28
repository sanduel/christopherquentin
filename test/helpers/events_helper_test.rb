require "test_helper"

class EventsHelperTest < ActionView::TestCase
  include EventsHelper

  DEFAULT_ZONE = Event::DISPLAY_ZONES.first[0]

  setup do
    # A fixed instant: 2026-06-14 19:00 UTC -> 3:00 PM EDT
    @time = Time.utc(2026, 6, 14, 19, 0, 0)
  end

  test "event_date_tag renders the default-zone date with timezone data attributes" do
    html = event_date_tag(@time)

    assert_match %r{data-timezone-target="datetime"}, html
    assert_match %r{data-format="date"}, html
    assert_match %r{data-utc="#{Regexp.escape(@time.utc.iso8601)}"}, html
    # Default zone is ET -> Sunday Jun 14, 2026
    assert_match %r{Sunday Jun 14, 2026}, html
  end

  test "event_time_tag renders the default-zone time with timezone data attributes" do
    html = event_time_tag(@time)

    assert_match %r{data-timezone-target="datetime"}, html
    assert_match %r{data-format="time"}, html
    assert_match %r{data-utc="#{Regexp.escape(@time.utc.iso8601)}"}, html
    # Default zone label is ET, with a zone-bare time so the client can re-label
    # without a visible flicker -> "3:00 PM ET"
    assert_match %r{3:00 PM ET}, html
    refute_match %r{EDT}, html
  end

  test "event_date_tag and event_time_tag apply extra css classes" do
    assert_match %r{class="[^"]*text-moss}, event_date_tag(@time, classes: "text-moss")
    assert_match %r{class="[^"]*font-medium}, event_time_tag(@time, classes: "font-medium")
  end

  test "time tags return empty string for blank time" do
    assert_equal "", event_date_tag(nil)
    assert_equal "", event_time_tag(nil)
  end

  test "safe_event_url returns http(s) urls and nil for unsafe schemes" do
    assert_equal "https://zoom.us/j", safe_event_url("https://zoom.us/j")
    assert_equal "http://example.com", safe_event_url("http://example.com")
    assert_nil safe_event_url("javascript:alert(1)")
    assert_nil safe_event_url("data:text/html,x")
    assert_nil safe_event_url("example.com")
    assert_nil safe_event_url(nil)
  end

  test "event_timezone_select renders a select wired to the timezone controller" do
    html = event_timezone_select

    assert_match %r{<select}, html
    assert_match %r{data-timezone-target="select"}, html
    assert_match %r{data-action="[^"]*timezone#change}, html
  end

  test "event_timezone_select includes each display zone plus a local option" do
    html = event_timezone_select

    Event::DISPLAY_ZONES.each do |zone, label|
      assert_match %r{<option[^>]*value="#{Regexp.escape(zone)}"[^>]*>#{Regexp.escape(label)}</option>}, html
    end
    # Local/browser zone option, value resolved client-side
    assert_match %r{value="local"}, html
  end
end
