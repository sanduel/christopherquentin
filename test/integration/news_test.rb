require "test_helper"

class NewsTest < ActionDispatch::IntegrationTest
  test "renders header" do
    get news_path
    assert_response :success
    assert_match(/News & Press.*mentions/m, response.body)
    assert_select "h1.font-serif", text: /world's/i
  end

  test "renders at least one year group" do
    get news_path
    assert_select "[data-year-group]", minimum: 1
  end

  test "renders press items with source + title + kind chip" do
    get news_path
    assert_select "[data-press-item]" do
      assert_select "*", text: /Slippedisc|RCM|Pizzicato|Dartmouth/i
    end
  end

  test "press item title link opens external URL in new tab" do
    get news_path
    assert_select "[data-press-item] a[target='_blank'][rel='noopener']"
  end

  test "kind chip shown for each item" do
    get news_path
    assert_match(/obituary|interview|feature|listing/i, response.body)
  end
end
