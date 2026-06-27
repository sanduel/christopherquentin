require "test_helper"

class WordpressImporterTest < ActiveSupport::TestCase
  def image_path
    Rails.root.join("test/fixtures/files/wp_sample.png").to_s
  end

  # A compact WXR export covering each case the importer must handle.
  def wxr
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0"
        xmlns:content="http://purl.org/rss/1.0/modules/content/"
        xmlns:dc="http://purl.org/dc/elements/1.1/"
        xmlns:wp="http://wordpress.org/export/1.2/">
      <channel>
        <item>
          <title>Diana Laird</title>
          <content:encoded><![CDATA[<p>A beautiful <strong>Magnolia</strong> tree.</p><p>So we plant.</p>]]></content:encoded>
          <dc:creator>samuel</dc:creator>
          <wp:post_id>101</wp:post_id>
          <wp:post_type>post</wp:post_type>
          <wp:status>publish</wp:status>
          <wp:post_date>2021-06-15 01:16:14</wp:post_date>
        </item>
        <item>
          <title>Pending Person</title>
          <content:encoded><![CDATA[Awaiting review.]]></content:encoded>
          <wp:post_id>102</wp:post_id>
          <wp:post_type>post</wp:post_type>
          <wp:status>pending</wp:status>
          <wp:post_date>2021-10-07 00:35:34</wp:post_date>
        </item>
        <item>
          <title>Empty Body</title>
          <content:encoded><![CDATA[   ]]></content:encoded>
          <wp:post_id>103</wp:post_id>
          <wp:post_type>post</wp:post_type>
          <wp:status>publish</wp:status>
          <wp:post_date>2021-10-07 00:35:34</wp:post_date>
        </item>
        <item>
          <title>Action Shot</title>
          <wp:post_id>201</wp:post_id>
          <wp:post_type>attachment</wp:post_type>
          <wp:status>inherit</wp:status>
          <wp:attachment_url>https://example.com/action-shot.jpg</wp:attachment_url>
        </item>
        <item>
          <title>A PDF</title>
          <wp:post_id>202</wp:post_id>
          <wp:post_type>attachment</wp:post_type>
          <wp:status>inherit</wp:status>
          <wp:attachment_url>https://example.com/doc.pdf</wp:attachment_url>
        </item>
        <item>
          <title>RCM Chinese New Year Concert</title>
          <content:encoded><![CDATA[<p>An evening of music.</p>]]></content:encoded>
          <wp:post_id>301</wp:post_id>
          <wp:post_type>mec-events</wp:post_type>
          <wp:status>publish</wp:status>
          <wp:post_date>2020-02-06 16:37:45</wp:post_date>
          <wp:postmeta><wp:meta_key>mec_start_date</wp:meta_key><wp:meta_value>2020-01-24</wp:meta_value></wp:postmeta>
          <wp:postmeta><wp:meta_key>mec_start_time_hour</wp:meta_key><wp:meta_value>7</wp:meta_value></wp:postmeta>
          <wp:postmeta><wp:meta_key>mec_start_time_minutes</wp:meta_key><wp:meta_value>30</wp:meta_value></wp:postmeta>
          <wp:postmeta><wp:meta_key>mec_start_time_ampm</wp:meta_key><wp:meta_value>PM</wp:meta_value></wp:postmeta>
          <wp:postmeta><wp:meta_key>mec_end_date</wp:meta_key><wp:meta_value>2020-01-24</wp:meta_value></wp:postmeta>
          <wp:postmeta><wp:meta_key>mec_end_time_hour</wp:meta_key><wp:meta_value>9</wp:meta_value></wp:postmeta>
          <wp:postmeta><wp:meta_key>mec_end_time_minutes</wp:meta_key><wp:meta_value>30</wp:meta_value></wp:postmeta>
          <wp:postmeta><wp:meta_key>mec_end_time_ampm</wp:meta_key><wp:meta_value>PM</wp:meta_value></wp:postmeta>
        </item>
        <item>
          <title>Watermelon Feta Salad</title>
          <content:encoded><![CDATA[<!-- wp:wpzoom-recipe-card/block-recipe-card {"recipeTitle":"Watermelon Feta Salad","summary":"Summer salad.","ingredients":[{"name":["1 watermelon"]},{"name":["200g ",{"text":"feta"}]}],"steps":[{"name":["Cube the watermelon."]},{"name":["Toss with feta."]}]} /-->]]></content:encoded>
          <wp:post_id>401</wp:post_id>
          <wp:post_type>wpzoom_rcb</wp:post_type>
          <wp:status>publish</wp:status>
          <wp:post_date>2023-09-29 16:41:24</wp:post_date>
        </item>
      </channel>
      </rss>
    XML
  end

  def importer
    file = Tempfile.new([ "wxr", ".xml" ])
    file.write(wxr)
    file.rewind
    WordpressImporter.new(file.path)
  end

  # --- tributes ---
  test "imports posts as tributes, mapping fields and status" do
    result = importer.import_tributes
    assert_equal 2, result.created
    assert_equal 1, result.skipped, "empty-body post should be skipped"

    diana = Tribute.find_by!(wp_post_id: 101)
    assert_equal "Diana Laird", diana.name
    assert_equal "published", diana.status
    assert_includes diana.content, "Magnolia"
    refute_includes diana.content, "<strong>", "HTML must be stripped"
    assert_equal "So we plant.", diana.content.split("\n").last.strip
    assert_equal Time.zone.parse("2021-06-15 01:16:14"), diana.created_at

    assert_equal "pending", Tribute.find_by!(wp_post_id: 102).status
  end

  test "tribute import is idempotent on wp_post_id" do
    importer.import_tributes
    assert_no_difference -> { Tribute.count } do
      importer.import_tributes
    end
  end

  # --- gallery ---
  # download() is the network boundary; stub it to return the real fixture
  # image so the test exercises the genuine attach + record logic offline.
  def with_stubbed_download(imp)
    bytes = File.binread(image_path)
    imp.define_singleton_method(:download) { |_url| StringIO.new(bytes) }
    yield imp
  end

  test "imports image attachments as gallery photos and skips non-images" do
    imp = importer
    with_stubbed_download(imp) { result = imp.import_gallery; @result = result }
    assert_equal 1, @result.created
    assert_equal 1, @result.skipped, "the PDF should be skipped"

    photo = GalleryPhoto.find_by!(wp_post_id: 201)
    assert photo.photo.attached?
    assert_equal "Action Shot", photo.caption
  end

  test "gallery import does not re-download already-attached photos" do
    imp = importer
    with_stubbed_download(imp) { imp.import_gallery }
    imp2 = importer
    assert_no_difference -> { GalleryPhoto.count } do
      with_stubbed_download(imp2) { imp2.import_gallery }
    end
  end

  test "gallery import re-uploads when the stored object is missing" do
    imp = importer
    with_stubbed_download(imp) { imp.import_gallery }
    photo = GalleryPhoto.find_by!(wp_post_id: 201)
    blob = photo.photo.blob
    # Simulate a dangling attachment: blob record exists, object is gone.
    blob.service.delete(blob.key)
    assert_not blob.service.exist?(blob.key)

    imp2 = importer
    with_stubbed_download(imp2) { imp2.import_gallery }

    photo.reload
    assert photo.photo.attached?
    assert photo.photo.blob.service.exist?(photo.photo.blob.key), "object should be re-uploaded"
  end

  # --- events ---
  test "imports mec-events with assembled start/end times" do
    result = importer.import_events
    assert_equal 1, result.created
    event = Event.find_by!(wp_post_id: 301)
    assert_equal "RCM Chinese New Year Concert", event.title
    assert_equal "concert", event.event_type
    assert event.published
    assert_equal Time.zone.parse("2020-01-24 19:30"), event.starts_at
    assert_equal Time.zone.parse("2020-01-24 21:30"), event.ends_at
  end

  # --- recipes ---
  test "imports wpzoom recipe cards parsing ingredients and steps" do
    result = importer.import_recipes
    assert_equal 1, result.created
    recipe = Recipe.find_by!(wp_post_id: 401)
    assert_equal "Watermelon Feta Salad", recipe.title
    assert_equal "Christopher Quentin", recipe.submitter_name
    assert_includes recipe.ingredients, "1 watermelon"
    assert_includes recipe.ingredients, "200g feta"
    assert_includes recipe.instructions, "Cube the watermelon."
    assert_equal "published", recipe.status
  end
end
