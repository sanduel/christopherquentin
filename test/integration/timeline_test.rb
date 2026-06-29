require "test_helper"

class TimelineTest < ActionDispatch::IntegrationTest
  def setup
    Memory.delete_all
    Memory.create!(date: Date.new(2002, 9, 1), content: "Mass Row", location: "Hanover, NH",
                   name: "Friend", email: "f@a.com", kind: :text, status: :published)
    Memory.create!(date: Date.new(2014, 6, 15), content: "Munich concert", location: "Munich, Germany",
                   name: "Colleague", email: "c@a.com", kind: :text, status: :published)
    Memory.create!(date: Date.new(2019, 5, 12), content: "Stavanger rehearsal", location: "Stavanger, Norway",
                   name: "Student", email: "s@a.com", kind: :text, status: :published)
  end

  test "timeline renders the header eyebrow" do
    get memories_path
    assert_response :success
    assert_match(/Timeline.*memories/m, response.body)
    assert_select "span.font-mono", text: /Timeline/
  end

  test "timeline renders the Share a memory CTA" do
    get memories_path
    assert_select "button, a", text: /Share a memory/i
  end

  test "timeline renders year filter chips for each unique year" do
    get memories_path
    assert_select "[data-year-filter]" do
      assert_select "a, button", text: "All"
      assert_select "a, button", text: "2002"
      assert_select "a, button", text: "2014"
      assert_select "a, button", text: "2019"
    end
  end

  test "All chip is active when no year filter" do
    get memories_path
    assert_select "[data-year-filter] .bg-ink.text-white-bg", text: "All"
  end

  test "Year chip is active when filtered" do
    get memories_path, params: { year: 2014 }
    assert_select "[data-year-filter] .bg-ink.text-white-bg", text: "2014"
  end

  test "filtering by year renders only that year's memories" do
    get memories_path, params: { year: 2014 }
    assert_match "Munich concert", response.body
    assert_no_match "Mass Row", response.body
    assert_no_match "Stavanger rehearsal", response.body
  end

  test "year markers render he-was-N subtext" do
    get memories_path
    assert_match "he was 18", response.body
    assert_match "he was 30", response.body
    assert_match "he was 35", response.body
  end

  test "year markers use tightened vertical spacing" do
    get memories_path
    # Year markers carry the reduced top/bottom margins rather than the original airier ones.
    assert_select "div.flex.justify-center.mt-12.mb-8", minimum: 1
  end

  test "memory cards render content, name, location" do
    get memories_path
    assert_match "Mass Row", response.body
    assert_match "Hanover, NH", response.body
    assert_match "Friend", response.body
  end

  test "empty year filter shows Clear filter link" do
    get memories_path, params: { year: 2099 }
    assert_match(/No memories for 2099/, response.body)
    assert_select "a[href=?]", memories_path, text: /Clear filter/i
  end

  test "photo memory card renders the photo slot" do
    photo_memory = Memory.new(
      date: Date.new(2014, 6, 15), content: "On stage.",
      name: "Photographer", email: "p@a.com", kind: :photo, status: :published
    )
    photo_memory.photos.attach(
      io: StringIO.new("fake image bytes"),
      filename: "test.jpg",
      content_type: "image/jpeg"
    )
    photo_memory.save!

    get memories_path

    assert_select "[data-memory-id='#{photo_memory.id}'][data-kind='photo']"
  end

  test "audio memory card renders the audio player controller" do
    audio_memory = Memory.new(
      date: Date.new(2018, 7, 1), content: "A clip.",
      name: "Recorder", email: "r@a.com", kind: :audio, audio_label: "Cape Cod, summer 2018",
      audio_length: "1:42", status: :published
    )
    audio_memory.audio_clip.attach(
      io: StringIO.new("fake audio bytes"),
      filename: "test.mp3",
      content_type: "audio/mpeg"
    )
    audio_memory.save!

    get memories_path

    assert_select "[data-controller~='audio-player']"
    assert_select "[data-memory-id='#{audio_memory.id}'][data-kind='audio']"
  end

  test "memory card with replies renders only published ones" do
    memory = Memory.create!(
      date: Date.today, content: "A note.",
      name: "Author", email: "a@b.com", kind: :text, status: :published
    )
    memory.replies.create!(name: "Visitor", email: "v@b.com", body: "Beautiful.", status: :published)
    memory.replies.create!(name: "Other", email: "o@b.com", body: "PendingShouldNotShow", status: :pending)

    get memories_path

    assert_match "Beautiful.", response.body
    assert_no_match "PendingShouldNotShow", response.body
  end

  test "memory card has a hidden reply composer that toggles" do
    Memory.create!(date: Date.today, content: "x", name: "A", email: "a@b.com", kind: :text, status: :published)

    get memories_path

    # Composer markup present but hidden by default
    assert_select "[data-reply-toggle-target='composer'][hidden]"
    # Form for reply submission targets the nested route
    assert_select "form[action*='/replies']"
  end
end
