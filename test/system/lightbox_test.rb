require "application_system_test_case"

class LightboxTest < ApplicationSystemTestCase
  # This test exercises lightbox JS behaviour only. Full-size images are Active
  # Storage variants whose generation depends on the host image backend
  # (libvips/imagemagick); a missing backend yields an async 500 on the image
  # request that is irrelevant here. Don't let that fail the interaction test —
  # the assertions below still require the page to render and the JS to run.
  setup { Capybara.raise_server_errors = false }
  teardown { Capybara.raise_server_errors = true }

  def make_photo(caption:, sort_order:)
    gp = GalleryPhoto.new(status: :published, caption: caption, sort_order: sort_order)
    gp.photo.attach(io: File.open(Rails.root.join("test/fixtures/files/wp_sample.png")),
                    filename: "x#{sort_order}.png", content_type: "image/png")
    gp.save!
    gp
  end

  test "gallery photos open in a navigable lightbox" do
    make_photo(caption: "First photo", sort_order: 0)
    make_photo(caption: "Second photo", sort_order: 1)

    visit gallery_path

    # Dialog starts closed.
    assert_no_selector "dialog[aria-label='Photo viewer'][open]"

    # Clicking a thumbnail opens the lightbox on that photo.
    first("[data-lightbox-target='item']").click
    assert_selector "dialog[aria-label='Photo viewer'][open]"
    assert_selector "[data-lightbox-target='caption']", text: "First photo"

    # Next advances through the set.
    find("[aria-label='Next photo']").click
    assert_selector "[data-lightbox-target='caption']", text: "Second photo"

    # The left arrow key pages back.
    find("dialog[aria-label='Photo viewer']").send_keys(:arrow_left)
    assert_selector "[data-lightbox-target='caption']", text: "First photo"

    # Escape closes the lightbox.
    find("dialog[aria-label='Photo viewer']").send_keys(:escape)
    assert_no_selector "dialog[aria-label='Photo viewer'][open]"
  end
end
