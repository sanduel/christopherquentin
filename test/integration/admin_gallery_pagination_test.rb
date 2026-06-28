require "test_helper"

class AdminGalleryPaginationTest < ActionDispatch::IntegrationTest
  include SignInHelper

  def create_photos(n)
    n.times do |i|
      gp = GalleryPhoto.new(sort_order: i, caption: "Photo #{i}")
      gp.photo.attach(
        io: File.open(Rails.root.join("test/fixtures/files/wp_sample.png")),
        filename: "p#{i}.png", content_type: "image/png"
      )
      gp.save!
    end
  end

  test "gallery index paginates instead of rendering every photo" do
    sign_in_admin
    per = Admin::GalleryPhotosController::PER_PAGE
    create_photos(per + 1)

    get admin_gallery_photos_path
    assert_response :success
    assert_select "img.aspect-square", per, "page 1 should render exactly PER_PAGE thumbnails"

    get admin_gallery_photos_path(page: 2)
    assert_response :success
    assert_select "img.aspect-square", 1, "page 2 should render the remaining photo"
  end
end
