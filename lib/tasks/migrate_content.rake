require "net/http"
require "json"
require "uri"

namespace :migrate do
  desc "Import all content from WordPress site via REST API"
  task all: :environment do
    Rake::Task["migrate:tributes"].invoke
    Rake::Task["migrate:recipes"].invoke
    Rake::Task["migrate:trees"].invoke
  end

  desc "Import tributes from WordPress (category: Memorial, id: 67)"
  task tributes: :environment do
    puts "Importing tributes..."
    posts = fetch_all_posts(categories: 67)

    # Also fetch Uncategorized posts that aren't in other categories
    uncategorized = fetch_all_posts(categories: 1)
    # Filter out posts that are also in Recipes (86) or Trees (73)
    uncategorized.reject! { |p| (p["categories"] & [ 86, 73 ]).any? }
    posts += uncategorized

    # Also fetch Family posts
    family = fetch_all_posts(categories: 70)
    posts += family

    # Deduplicate by post ID
    posts.uniq! { |p| p["id"] }

    imported = 0
    skipped = 0

    posts.each do |post|
      name = strip_html(post.dig("title", "rendered")).strip
      content = strip_html(post.dig("content", "rendered")).strip

      next if name.blank? || content.blank?

      if Tribute.exists?(name: name)
        skipped += 1
        next
      end

      Tribute.create!(
        name: name,
        content: content,
        status: :published,
        created_at: post["date"],
        updated_at: post["modified"]
      )
      imported += 1
    end

    puts "  Imported #{imported} tributes, skipped #{skipped} duplicates"
  end

  desc "Import recipes from WordPress (category: Recipes, id: 86)"
  task recipes: :environment do
    puts "Importing recipes..."
    posts = fetch_all_posts(categories: 86)

    # Also check uncategorized for known recipe slugs
    known_recipe_slugs = %w[butter-chicken-from-didi risgrot]
    uncategorized = fetch_all_posts(categories: 1)
    recipe_extras = uncategorized.select { |p| known_recipe_slugs.include?(p["slug"]) }
    posts += recipe_extras
    posts.uniq! { |p| p["id"] }

    imported = 0
    skipped = 0

    posts.each do |post|
      title = strip_html(post.dig("title", "rendered")).strip
      raw_content = post.dig("content", "rendered") || ""
      text_content = strip_html(raw_content).strip

      next if title.blank? || text_content.blank?

      if Recipe.exists?(title: title)
        skipped += 1
        next
      end

      # Try to parse ingredients and instructions from the HTML
      ingredients, instructions, story = parse_recipe(raw_content)

      Recipe.create!(
        title: title,
        submitter_name: extract_recipe_author(title, text_content),
        ingredients: ingredients.presence || text_content,
        instructions: instructions.presence || "See ingredients field for full recipe.",
        story: story,
        status: :published,
        created_at: post["date"],
        updated_at: post["modified"]
      )
      imported += 1
    end

    puts "  Imported #{imported} recipes, skipped #{skipped} duplicates"
  end

  desc "Import tree stories from WordPress (category: Trees, id: 73)"
  task trees: :environment do
    puts "Importing tree stories..."
    # Disable geocoding during import - addresses will be geocoded later
    Geocoder.configure(lookup: :test, ip_lookup: :test)
    Geocoder::Lookup::Test.set_default_stub(
      [ { "latitude" => 0.0, "longitude" => 0.0, "address" => "Unknown", "country" => "Unknown" } ]
    )

    posts = fetch_all_posts(categories: 73)

    imported = 0
    skipped = 0

    posts.each do |post|
      name = strip_html(post.dig("title", "rendered")).strip
      story = strip_html(post.dig("content", "rendered")).strip

      next if name.blank?

      if Tree.exists?(name: name)
        skipped += 1
        next
      end

      # Extract location from content if possible
      address = extract_address(story)

      Tree.create!(
        name: name,
        story: story,
        address: address.presence || "Unknown",
        tree_count: extract_tree_count(story),
        status: :published,
        created_at: post["date"],
        updated_at: post["modified"]
      )
      imported += 1
    end

    puts "  Imported #{imported} tree stories, skipped #{skipped} duplicates"
  end

  desc "Download gallery photos from WordPress and attach to GalleryPhoto records"
  task gallery: :environment do
    puts "Downloading gallery photos..."
    require "open-uri"

    photo_urls = [
      "https://christopherquentin.com/wp-content/uploads/2020/02/Christopher-Quentin-Action-Shot-1024x683.jpg",
      "https://christopherquentin.com/wp-content/uploads/2020/02/Samuel-McMullen-Chris-0135-684x1024.jpg",
      "https://christopherquentin.com/wp-content/uploads/2017/01/Chris-1024x683.jpg",
      "https://christopherquentin.com/wp-content/uploads/2020/02/Chris-Demo-4-683x1024.jpg",
      "https://christopherquentin.com/wp-content/uploads/2020/02/Samuel-McMullen-for-Chris-10918-1024x632.jpg",
      "https://christopherquentin.com/wp-content/uploads/2017/01/Chris-1-of-1-3-683x1024.jpg",
      "https://christopherquentin.com/wp-content/uploads/2017/01/Chris-1-of-1-1024x683.jpg",
      "https://christopherquentin.com/wp-content/uploads/2017/01/Samuel-McMullen-Chris-0035-1024x683.jpg",
      "https://christopherquentin.com/wp-content/uploads/2020/06/img_20050613_164104-1024x1024.jpg",
      "https://christopherquentin.com/wp-content/uploads/2020/06/002-1024x1024.jpg",
      "https://christopherquentin.com/wp-content/uploads/2020/06/026-3-1024x1024.jpg",
      "https://christopherquentin.com/wp-content/uploads/2020/06/465-1024x1024.jpg",
      "https://christopherquentin.com/wp-content/uploads/2020/06/IMG_0101-1024x1024.jpg",
      "https://christopherquentin.com/wp-content/uploads/2020/06/DSCF0025-1024x1024.jpg",
      "https://christopherquentin.com/wp-content/uploads/2020/06/IMG_2340-1024x1024.jpeg",
      "https://christopherquentin.com/wp-content/uploads/2020/06/IMG_2557-1024x1024.jpeg",
      "https://christopherquentin.com/wp-content/uploads/2020/06/IMG_2833-1024x1024.jpeg",
      "https://christopherquentin.com/wp-content/uploads/2020/06/IMG_2838-1024x1024.jpeg",
      "https://christopherquentin.com/wp-content/uploads/2020/06/IMG_3430-1024x1024.jpeg",
      "https://christopherquentin.com/wp-content/uploads/2020/06/IMG_3893-1024x1024.jpeg",
      "https://christopherquentin.com/wp-content/uploads/2020/06/IMG_3865-1024x1024.jpeg",
      "https://christopherquentin.com/wp-content/uploads/2020/06/IMG_8484-1024x1024.jpeg",
      "https://christopherquentin.com/wp-content/uploads/2020/06/IMG_8494-1024x1024.jpeg",
      "https://christopherquentin.com/wp-content/uploads/2020/06/IMG_8486-1024x1024.jpeg",
      "https://christopherquentin.com/wp-content/uploads/2020/06/IMG_8485-1024x1024.jpeg",
      "https://christopherquentin.com/wp-content/uploads/2020/06/IMG_8776-1024x1024.jpeg",
      "https://christopherquentin.com/wp-content/uploads/2020/06/IMG_8777-1024x1024.jpeg",
      "https://christopherquentin.com/wp-content/uploads/2020/06/IMG_8779-1024x1024.jpeg",
      "https://christopherquentin.com/wp-content/uploads/2020/06/IMG_8780-1024x1024.jpeg",
      "https://christopherquentin.com/wp-content/uploads/2020/06/DSC02454-1024x1024.jpg",
      "https://christopherquentin.com/wp-content/uploads/2020/06/Ashby-1024x1024.jpg",
      "https://christopherquentin.com/wp-content/uploads/2020/06/0BE51E70-ABD7-4E33-A4A7-F58A88BC550E-1024x1024.jpeg",
      "https://christopherquentin.com/wp-content/uploads/2020/06/IMG_0013-1024x1024.jpeg",
      "https://christopherquentin.com/wp-content/uploads/2020/06/Santacroce1-1024x1024.jpg",
      "https://christopherquentin.com/wp-content/uploads/2020/06/DSCN0824-1024x1024.jpg",
      "https://christopherquentin.com/wp-content/uploads/2020/06/Mio-1-943x629.png",
      "https://christopherquentin.com/wp-content/uploads/2020/06/GodsonGodfather2012-1024x1024.jpeg",
      "https://christopherquentin.com/wp-content/uploads/2020/06/15-bimbone-1024x1024.jpg",
      "https://christopherquentin.com/wp-content/uploads/2020/06/12-bimbone-1024x1024.jpg",
      "https://christopherquentin.com/wp-content/uploads/2020/06/20190725-_XH11302-1024x676.jpg",
      "https://christopherquentin.com/wp-content/uploads/2021/06/65954031_10101604520889076_2432820307115900928_n_10101604520884086.jpg"
    ]

    downloaded = 0
    failed = 0

    photo_urls.each_with_index do |url, index|
      filename = File.basename(URI.parse(url).path)

      if GalleryPhoto.joins(:photo_attachment).where(active_storage_attachments: { name: "photo" }).any? { |gp| gp.photo.filename.to_s == filename }
        puts "  Skipping #{filename} (already exists)"
        next
      end

      begin
        file = URI.parse(url).open(ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE)
        photo = GalleryPhoto.new(sort_order: index)
        photo.photo.attach(io: file, filename: filename, content_type: content_type_for(filename))
        photo.save!
        downloaded += 1
        puts "  Downloaded #{filename}"
      rescue => e
        puts "  Failed to download #{filename}: #{e.message}"
        failed += 1
      end
    end

    puts "  Downloaded #{downloaded} photos, #{failed} failures"
  end
end

# Helper methods

def fetch_all_posts(categories:, per_page: 100)
  all_posts = []
  page = 1

  loop do
    uri = URI("https://christopherquentin.com/wp-json/wp/v2/posts")
    uri.query = URI.encode_www_form(categories: categories, per_page: per_page, page: page)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Get.new(uri)
    response = http.request(request)
    break unless response.is_a?(Net::HTTPSuccess)

    posts = JSON.parse(response.body)
    break if posts.empty?

    all_posts += posts
    total_pages = response["X-WP-TotalPages"].to_i
    break if page >= total_pages

    page += 1
  end

  all_posts
end

def strip_html(html)
  return "" if html.blank?
  # Remove HTML tags, decode entities, clean up whitespace
  text = html.gsub(/<[^>]+>/, " ")
  text = text.gsub(/&nbsp;/, " ")
  text = text.gsub(/&#8217;/, "'")
  text = text.gsub(/&#8216;/, "'")
  text = text.gsub(/&#8220;/, '"')
  text = text.gsub(/&#8221;/, '"')
  text = text.gsub(/&#8211;/, "-")
  text = text.gsub(/&#8212;/, "--")
  text = text.gsub(/&amp;/, "&")
  text = text.gsub(/&lt;/, "<")
  text = text.gsub(/&gt;/, ">")
  text = text.gsub(/&quot;/, '"')
  text = text.gsub(/\s+/, " ")
  text.strip
end

def parse_recipe(html)
  ingredients = ""
  instructions = ""
  story = ""

  # Try to find ingredient lists (often in <ul> or <ol>)
  if html =~ /ingredients?/i
    # Extract list items near "ingredient" keyword
    section = html.split(/instructions?|preparation|method|directions?/i).first
    if section
      items = section.scan(/<li[^>]*>(.*?)<\/li>/mi).flatten
      ingredients = items.map { |i| strip_html(i).strip }.reject(&:blank?).join("\n") if items.any?
    end
  end

  # Try to find instructions
  if html =~ /instructions?|preparation|method|directions?/i
    section = html.split(/instructions?|preparation|method|directions?/i).last
    if section
      items = section.scan(/<li[^>]*>(.*?)<\/li>/mi).flatten
      if items.any?
        instructions = items.map.with_index { |i, idx| "#{idx + 1}. #{strip_html(i).strip}" }.reject { |i| i =~ /^\d+\.\s*$/ }.join("\n")
      else
        instructions = strip_html(section).strip
      end
    end
  end

  # If parsing failed, put everything in ingredients
  if ingredients.blank? && instructions.blank?
    ingredients = strip_html(html).strip
    instructions = "See above."
  end

  [ ingredients, instructions, story ]
end

def extract_recipe_author(title, content)
  # Try to extract author from title patterns like "Recipe from Diana" or "Tiramisu with Rebecca Rossi"
  if title =~ /from\s+(.+)/i
    $1.strip
  elsif title =~ /with\s+(.+)/i
    $1.strip
  else
    "Christopher's kitchen"
  end
end

def extract_address(story)
  # Look for common location patterns
  locations = story.scan(/(?:in|at|near)\s+([A-Z][^,.]+(?:,\s*[A-Z][^,.]+)?)/i)
  locations.flatten.first
end

def extract_tree_count(story)
  match = story.match(/(\d+)\s+trees?/i)
  match ? match[1].to_i : 1
end

def content_type_for(filename)
  case File.extname(filename).downcase
  when ".jpg", ".jpeg" then "image/jpeg"
  when ".png" then "image/png"
  when ".gif" then "image/gif"
  when ".webp" then "image/webp"
  else "image/jpeg"
  end
end
