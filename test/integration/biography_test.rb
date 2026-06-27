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
end
