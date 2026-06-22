require "test_helper"

class TreesIndexTest < ActionDispatch::IntegrationTest
  test "renders header with lento e sereno" do
    get trees_path
    assert_response :success
    assert_select ".text-eyebrow", text: /Op\. VI · The Trees/
    assert_select "h1.font-serif", text: /A living memorial/
    assert_match "lento e sereno", response.body
  end

  test "renders world map placeholder with markers for published trees" do
    Tree.create!(name: "Ann Arbor tree", address: "Ann Arbor, MI",
                 latitude: 42.2808, longitude: -83.743,
                 status: :published, tree_count: 1)
    get trees_path
    assert_select "[data-section='trees-map']"
    assert_select "[data-tree-marker]"
  end

  test "renders stat callout" do
    get trees_path
    assert_match(/\d+ trees/, response.body)
    assert_match(/9 countries/, response.body)
  end

  test "renders inline add-tree form" do
    get trees_path
    assert_select "form[action=?]", trees_path do
      assert_select "input[name='tree[name]']"
      assert_select "input[name='tree[email]']"
      assert_select "input[name='tree[address]']"
    end
  end

  test "renders Why trees pull quote" do
    get trees_path
    assert_match(/plant a tree before he'd write a letter/i, response.body)
  end

  test "renders Other ways in grid" do
    get trees_path
    assert_select "[data-section='other-ways']" do
      assert_select "a[href=?]", new_bee_hive_path
      assert_select "a[href=?]", new_memory_path
      assert_select "a[href=?]", funds_path
    end
  end

  test "links to full interactive map" do
    get trees_path
    assert_select "a[href=?]", map_path, text: /full map/i
  end
end
