require "test_helper"

class StyleGuideTest < ActionDispatch::IntegrationTest
  test "style guide is reachable in test environment" do
    get "/style-guide"
    assert_response :success
    assert_select "h1", /Style Guide/
  end

  test "style guide renders palette swatches" do
    get "/style-guide"
    # Style guide still shows Garden swatches as historical reference
    %w[cream linen ink sage moss rose].each do |color|
      assert_select "[data-swatch=?]", color
    end
  end

  test "style guide renders the three type specimens" do
    get "/style-guide"
    assert_select ".font-serif", minimum: 1
    assert_select ".font-sans", minimum: 1
    assert_select ".font-mono", minimum: 1
  end

  test "style guide renders eyebrows" do
    get "/style-guide"
    assert_select ".text-eyebrow", minimum: 2
  end

  test "style guide renders accent rule on with-rule eyebrow" do
    get "/style-guide"
    assert_select "span.bg-accent"
  end
end
