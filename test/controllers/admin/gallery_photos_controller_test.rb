require "test_helper"

class Admin::GalleryPhotosControllerTest < ActionDispatch::IntegrationTest
  include SignInHelper

  def build_photo(**attrs)
    gp = GalleryPhoto.new(**attrs)
    gp.photo.attach(io: File.open(Rails.root.join("test/fixtures/files/wp_sample.png")),
                    filename: "x.png", content_type: "image/png")
    gp.save!
    gp
  end

  test "PATCH with bio_grid=true flags the photo for the bio grid" do
    sign_in_admin
    photo = build_photo(caption: "x", bio_grid: false)

    patch admin_gallery_photo_path(photo), params: { bio_grid: true }

    assert photo.reload.bio_grid?
    assert_redirected_to admin_gallery_photos_path
  end

  test "PATCH with bio_grid=false removes the photo from the bio grid" do
    sign_in_admin
    photo = build_photo(caption: "x", bio_grid: true)

    patch admin_gallery_photo_path(photo), params: { bio_grid: false }

    assert_not photo.reload.bio_grid?
  end

  test "updating via the edit form persists bio_grid" do
    sign_in_admin
    photo = build_photo(caption: "x", bio_grid: false)

    patch admin_gallery_photo_path(photo), params: { gallery_photo: { bio_grid: "1" } }

    assert photo.reload.bio_grid?
  end
end
