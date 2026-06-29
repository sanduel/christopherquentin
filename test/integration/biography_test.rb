require "test_helper"

class BiographyTest < ActionDispatch::IntegrationTest
  test "biography renders header with eyebrow + h1" do
    get chris_path
    assert_response :success
    assert_match(/Biography.*1984.*2020/m, response.body)
    assert_select "h1.font-serif", text: /Christopher McMullen-Laird/
  end

  test "biography renders the press blockquote" do
    get chris_path
    assert_select "blockquote" do
      assert_select "p", text: /scintillating charisma/
    end
  end

  test "biography renders Quick Facts dl" do
    get chris_path
    assert_select "dl.quick-facts" do
      assert_select "dt", minimum: 2
      assert_select "dd", minimum: 2
    end
  end

  test "biography renders Repertoire section with both groups" do
    get chris_path
    assert_select "[data-section='repertoire']" do
      assert_select "h3", text: /Operas Conducted/
      assert_select "h3", text: /Operas Assisted/
    end
  end

  test "Repertoire renders composers" do
    get chris_path
    assert_select "[data-section='repertoire']" do
      assert_select "*", text: /Mozart|Beethoven|Mahler/
    end
  end

  def attach_bio_photo(**attrs)
    gp = GalleryPhoto.new(**attrs)
    gp.photo.attach(io: File.open(Rails.root.join("test/fixtures/files/wp_sample.png")),
                    filename: "b.png", content_type: "image/png")
    gp.save!
    gp
  end

  test "bio grid renders flagged published photos in the sidebar" do
    3.times { |i| attach_bio_photo(sort_order: i, caption: "Bio #{i}", bio_grid: true, status: :published) }

    get chris_path
    assert_response :success
    assert_select "aside img", 3
  end

  test "bio grid keeps placeholders for unfilled slots and excludes unpublished/unflagged photos" do
    attach_bio_photo(sort_order: 0, caption: "shown", bio_grid: true, status: :published)
    attach_bio_photo(sort_order: 1, caption: "pending", bio_grid: true, status: :pending)
    attach_bio_photo(sort_order: 2, caption: "unflagged", bio_grid: false, status: :published)

    get chris_path
    assert_response :success
    assert_select "aside img", 1
  end
end
