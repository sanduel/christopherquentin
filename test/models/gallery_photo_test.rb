require "test_helper"

class GalleryPhotoTest < ActiveSupport::TestCase
  def build_photo(**attrs)
    gp = GalleryPhoto.new(**attrs)
    gp.photo.attach(io: File.open(Rails.root.join("test/fixtures/files/wp_sample.png")),
                    filename: "x.png", content_type: "image/png")
    gp.save!
    gp
  end

  test "bio_grid scope returns only photos flagged for the bio grid" do
    flagged = build_photo(caption: "in", bio_grid: true)
    build_photo(caption: "out", bio_grid: false)

    assert_equal [ flagged ], GalleryPhoto.bio_grid.to_a
  end
end
