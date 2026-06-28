require "test_helper"

class GalleryTest < ActionDispatch::IntegrationTest
  include SignInHelper

  def fixture_image
    Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/wp_sample.png"), "image/png")
  end

  def make_photo(status: :published, featured: false, portrait: false, caption: nil)
    gp = GalleryPhoto.new(status: status, featured: featured, portrait: portrait, caption: caption)
    gp.photo.attach(io: File.open(Rails.root.join("test/fixtures/files/wp_sample.png")), filename: "x.png", content_type: "image/png")
    gp.save!
    gp
  end

  # --- public gallery page ---
  test "public gallery shows published photos only" do
    make_photo(status: :published, caption: "Visible")
    make_photo(status: :pending,   caption: "Hidden pending")
    make_photo(status: :rejected,  caption: "Hidden rejected")

    get gallery_path
    assert_response :success
    assert_select "figcaption", text: "Visible"
    assert_select "figcaption", text: "Hidden pending", count: 0
    assert_select "figcaption", text: "Hidden rejected", count: 0
  end

  # --- public submission ---
  test "submitting photos creates pending gallery photos with submitter info" do
    assert_difference -> { GalleryPhoto.pending.count }, 2 do
      post submit_photos_path, params: {
        submitter_name: "Aunt May", submitter_email: "may@example.com",
        photos: [ fixture_image, fixture_image ]
      }
    end
    assert_redirected_to root_path
    photo = GalleryPhoto.pending.last
    assert_equal "Aunt May", photo.submitter_name
    assert photo.photo.attached?
  end

  test "submission without name/email is rejected" do
    assert_no_difference -> { GalleryPhoto.count } do
      post submit_photos_path, params: { submitter_name: "", submitter_email: "", photos: [ fixture_image ] }
    end
    assert_response :unprocessable_entity
  end

  # --- home page featured behaviour ---
  test "home page shows featured published photos when present" do
    make_photo(status: :published, featured: true,  caption: "Featured one")
    make_photo(status: :published, featured: false, caption: "Not featured")
    get root_path
    assert_response :success
    assert_select "img[alt=?]", "Featured one"
    assert_select "img[alt=?]", "Not featured", count: 0
  end

  test "home page falls back to recent published when nothing is featured" do
    make_photo(status: :published, featured: false, caption: "Recent published")
    get root_path
    assert_response :success
    assert_select "img[alt=?]", "Recent published"
  end

  # --- admin moderation + featured ---
  test "admin can approve a pending photo via status patch" do
    sign_in_admin
    photo = make_photo(status: :pending)
    patch admin_gallery_photo_path(photo), params: { status: :published }
    assert_equal "published", photo.reload.status
  end

  test "admin can toggle featured" do
    sign_in_admin
    photo = make_photo(status: :published, featured: false)
    patch admin_gallery_photo_path(photo), params: { featured: true }
    assert photo.reload.featured?
  end

  test "admin can toggle portrait" do
    sign_in_admin
    photo = make_photo(status: :published, portrait: false)
    patch admin_gallery_photo_path(photo), params: { portrait: true }
    assert photo.reload.portrait?
  end

  # --- lightbox wiring ---
  test "gallery page wires its photos into a lightbox with full-size sources" do
    make_photo(status: :published, caption: "Clickable")
    get gallery_path
    assert_response :success
    assert_select "[data-controller~=?]", "lightbox"
    assert_select "[data-lightbox-target=item][data-lightbox-src]", minimum: 1
  end

  test "home photo strip wires featured photos into a lightbox with full-size sources" do
    make_photo(status: :published, featured: true, caption: "Featured")
    get root_path
    assert_response :success
    assert_select "[data-controller~=?]", "lightbox"
    assert_select "[data-lightbox-target=item][data-lightbox-src]", minimum: 1
  end
end
