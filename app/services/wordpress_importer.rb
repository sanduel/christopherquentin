require "open-uri"

# Imports content from a WordPress WXR (eXtended RSS) export file.
#
#   WordpressImporter.new("path/to/export.xml").import_all
#
# Each importer is idempotent: records are keyed by their WordPress post id
# (wp_post_id), so re-running updates the existing record instead of creating
# a duplicate. Counts of created/updated/skipped are returned per type.
class WordpressImporter
  IMAGE_EXTENSIONS = %w[.jpg .jpeg .png .gif .webp].freeze

  Result = Struct.new(:created, :updated, :skipped, :errors, keyword_init: true) do
    def initialize(**) super; self.created ||= 0; self.updated ||= 0; self.skipped ||= 0; self.errors ||= []; end
    def record(existing) ; existing ? self.updated += 1 : self.created += 1 ; end
    def to_s ; "created=#{created} updated=#{updated} skipped=#{skipped} errors=#{errors.size}" ; end
  end

  def initialize(path, logger: nil)
    @path = path
    @logger = logger
    @doc = Nokogiri::XML(File.read(path))
    @doc.remove_namespaces!
  end

  def import_all
    {
      tributes: import_tributes,
      gallery:  import_gallery,
      events:   import_events,
      recipes:  import_recipes
    }
  end

  # --- Posts -> Tributes ---------------------------------------------------
  def import_tributes
    result = Result.new
    items_of_type("post").each do |item|
      body = html_to_text(encoded(item))
      if body.blank?
        result.skipped += 1
        log "skip tribute (empty body): #{text(item, 'title').inspect}"
        next
      end
      wp_id = post_id(item)
      tribute = Tribute.find_or_initialize_by(wp_post_id: wp_id)
      existing = tribute.persisted?
      tribute.name = text(item, "title").presence || "Anonymous"
      tribute.content = body
      tribute.status = tribute_status(item)
      apply_timestamps(tribute, item)
      tribute.save!
      result.record(existing)
    rescue => e
      result.errors << "tribute #{text(item, 'title').inspect}: #{e.message}"
    end
    result
  end

  # --- Attachments -> GalleryPhotos ----------------------------------------
  def import_gallery
    result = Result.new
    order = 0
    items_of_type("attachment").each do |item|
      url = text(item, "attachment_url")
      unless image_url?(url)
        result.skipped += 1
        next
      end
      order += 1
      wp_id = post_id(item)
      photo = GalleryPhoto.find_or_initialize_by(wp_post_id: wp_id)
      existing = photo.persisted?
      photo.caption = text(item, "title").presence
      photo.sort_order = order
      if !photo.photo.attached?
        io = download(url)
        next (result.skipped += 1) if io.nil?
        photo.photo.attach(io: io, filename: File.basename(URI.parse(url).path), content_type: content_type_for(url))
      elsif !object_present?(photo.photo)
        # Dangling attachment: the blob record exists but its object never
        # landed (e.g. an earlier failed upload). Re-upload the bytes to the
        # existing key rather than purging (deleting a missing key errors).
        io = download(url)
        next (result.skipped += 1) if io.nil?
        blob = photo.photo.blob
        blob.upload(io)
        blob.save!
      end
      photo.save!
      result.record(existing)
    rescue => e
      result.errors << "gallery #{url}: #{e.message}"
    end
    result
  end

  # --- mec-events -> Events ------------------------------------------------
  def import_events
    result = Result.new
    items_of_type("mec-events").each do |item|
      starts_at = mec_datetime(item, "start")
      next (result.skipped += 1) if starts_at.nil?
      wp_id = post_id(item)
      event = Event.find_or_initialize_by(wp_post_id: wp_id)
      existing = event.persisted?
      event.title = text(item, "title").presence || "Untitled event"
      event.description = html_to_text(encoded(item)).presence
      event.event_type = infer_event_type(text(item, "title"))
      event.starts_at = starts_at
      ends_at = mec_datetime(item, "end")
      event.ends_at = ends_at if ends_at && ends_at > starts_at
      event.published = status(item) == "publish"
      event.save!
      result.record(existing)
    rescue => e
      result.errors << "event #{text(item, 'title').inspect}: #{e.message}"
    end
    result
  end

  # --- wpzoom_rcb -> Recipes -----------------------------------------------
  def import_recipes
    result = Result.new
    items_of_type("wpzoom_rcb").each do |item|
      data = wpzoom_data(encoded(item))
      next (result.skipped += 1) if data.nil?
      wp_id = post_id(item)
      recipe = Recipe.find_or_initialize_by(wp_post_id: wp_id)
      existing = recipe.persisted?
      recipe.title = clean_text(data["recipeTitle"]).presence || text(item, "title").presence || "Untitled recipe"
      recipe.submitter_name = "Christopher Quentin"
      recipe.story = html_to_text(data["summary"]).presence
      recipe.ingredients = wpzoom_lines(data["ingredients"]).presence || "See recipe."
      recipe.instructions = wpzoom_lines(data["steps"]).presence || "See recipe."
      recipe.status = status(item) == "publish" ? :published : :pending
      apply_timestamps(recipe, item)
      recipe.save!
      result.record(existing)
    rescue => e
      result.errors << "recipe #{text(item, 'title').inspect}: #{e.message}"
    end
    result
  end

  private

  attr_reader :doc

  def items_of_type(type)
    doc.xpath("//item").select { |i| i.at_xpath("post_type")&.text == type }
  end

  def text(item, tag)
    item.at_xpath(tag)&.text.to_s.strip
  end

  def encoded(item)
    item.xpath("encoded").map(&:text).reject(&:empty?).first.to_s
  end

  def post_id(item)
    item.at_xpath("post_id")&.text.to_i
  end

  def status(item)
    item.at_xpath("status")&.text.to_s
  end

  def tribute_status(item)
    status(item) == "publish" ? :published : :pending
  end

  def apply_timestamps(record, item)
    date = parse_time(text(item, "post_date"))
    return if date.nil?
    record.created_at = date
    record.updated_at = date
  end

  def parse_time(str)
    return nil if str.blank? || str.start_with?("0000")
    Time.zone.parse(str)
  rescue ArgumentError
    nil
  end

  def html_to_text(html)
    return "" if html.blank?
    # Preserve paragraph/line breaks, then strip remaining tags and decode entities.
    text = html.gsub(%r{</p>|<br\s*/?>|</div>|</li>}i, "\n").gsub(/<[^>]+>/, "")
    CGI.unescapeHTML(text).gsub(/\r\n?/, "\n").gsub(/\n{3,}/, "\n\n").strip
  end

  def image_url?(url)
    return false if url.blank?
    ext = File.extname(URI.parse(url).path).downcase
    IMAGE_EXTENSIONS.include?(ext)
  rescue URI::InvalidURIError
    false
  end

  def content_type_for(url)
    case File.extname(URI.parse(url).path).downcase
    when ".png" then "image/png"
    when ".gif" then "image/gif"
    when ".webp" then "image/webp"
    else "image/jpeg"
    end
  end

  def object_present?(attached)
    blob = attached.blob
    blob.present? && blob.service.exist?(blob.key)
  rescue StandardError
    false
  end

  def download(url)
    URI.parse(url).open("User-Agent" => "ChristopherQuentinImporter/1.0", read_timeout: 30) { |f| StringIO.new(f.read) }
  rescue OpenURI::HTTPError, SocketError, Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED => e
    log "download failed #{url}: #{e.message}"
    nil
  end

  # MEC stores discrete start/end fields in postmeta.
  def mec_datetime(item, which)
    date = meta(item, "mec_#{which}_date")
    return nil if date.blank?
    hour = meta(item, "mec_#{which}_time_hour").to_i
    min  = meta(item, "mec_#{which}_time_minutes").to_i
    ampm = meta(item, "mec_#{which}_time_ampm")
    hour = 0 if hour == 12 && ampm == "AM"
    hour += 12 if ampm == "PM" && hour != 12
    Time.zone.parse("#{date} #{format('%02d:%02d', hour, min)}")
  rescue ArgumentError
    nil
  end

  def meta(item, key)
    item.xpath("postmeta").each do |m|
      return m.at_xpath("meta_value")&.text.to_s if m.at_xpath("meta_key")&.text == key
    end
    nil
  end

  def infer_event_type(title)
    t = title.to_s.downcase
    return :concert if t.include?("concert") || t.include?("recital")
    return :service if t.include?("service") || t.include?("memorial") || t.include?("funeral")
    return :webinar if t.include?("webinar") || t.include?("online") || t.include?("zoom")
    :concert
  end

  # WPZOOM recipe card stores its data as JSON in a Gutenberg block comment:
  #   <!-- wp:wpzoom-recipe-card/block-recipe-card {JSON} /-->
  def wpzoom_data(content)
    marker = content.index("wp:wpzoom-recipe-card/block-recipe-card")
    return nil if marker.nil?
    brace = content.index("{", marker)
    return nil if brace.nil?
    json = extract_balanced_json(content, brace)
    json && JSON.parse(json)
  rescue JSON::ParserError
    nil
  end

  def extract_balanced_json(str, start)
    depth = 0
    in_str = false
    escaped = false
    str[start..].each_char.with_index do |ch, i|
      if in_str
        if escaped then escaped = false
        elsif ch == "\\" then escaped = true
        elsif ch == '"' then in_str = false
        end
      else
        case ch
        when '"' then in_str = true
        when "{" then depth += 1
        when "}" then depth -= 1; return str[start, i + 1] if depth.zero?
        end
      end
    end
    nil
  end

  # WPZOOM ingredients/steps are arrays of entries whose text lives under
  # :name (ingredients) or :text (steps), each itself a list of strings and
  # token hashes. Inline {"type"=>"br"} tokens act as line breaks; some
  # recipes cram everything into one entry separated by those breaks.
  def wpzoom_lines(arr)
    return "" unless arr.is_a?(Array)
    arr.map { |entry| wpzoom_tokens(entry["name"] || entry["text"]) }
       .join("\n").split("\n").map(&:strip).reject(&:empty?).join("\n")
  end

  def wpzoom_tokens(node)
    case node
    when String then node
    when Array  then node.map { |tok| wpzoom_tokens(tok) }.join
    when Hash
      return "\n" if node["type"] == "br"
      return wpzoom_tokens(node["text"]) if node.key?("text")
      return wpzoom_tokens(node.dig("props", "children")) if node["props"].is_a?(Hash)
      ""
    else node.to_s
    end
  end

  # Decode stray \uXXXX (and the source's un-backslashed uXXXX) escapes, then
  # strip any resulting HTML — WPZOOM titles sometimes contain "...HAM<br>".
  def clean_text(str)
    return "" if str.blank?
    decoded = str.gsub(/\\?u([0-9a-fA-F]{4})/) { [ Regexp.last_match(1).hex ].pack("U") }
    html_to_text(decoded)
  end

  def log(msg)
    @logger&.info("[WordpressImporter] #{msg}")
  end
end
