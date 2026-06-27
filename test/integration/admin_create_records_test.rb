require "test_helper"

# Covers the "Admin: create new records + assign to user" feature (commit 00945a7),
# which added new/create actions, "+ New" links, and an "Assign to user" form field
# for several admin resources but left the routes and DB columns incomplete.
class AdminCreateRecordsTest < ActionDispatch::IntegrationTest
  include SignInHelper

  RESOURCES = %i[tributes memories trees recipes bee_hives].freeze

  # Bug A: index pages link to new_admin_*_path, which 500s when the route is absent.
  test "admin index pages render for every resource" do
    sign_in_admin
    RESOURCES.each do |resource|
      get public_send("admin_#{resource}_path")
      assert_response :success, "GET admin #{resource} index should render"
    end
  end

  # Bug A: the new form must be routable.
  test "admin new pages render for every resource" do
    sign_in_admin
    RESOURCES.each do |resource|
      get public_send("new_admin_#{resource.to_s.singularize}_path")
      assert_response :success, "GET admin new #{resource} should render"
    end
  end

  # Bug B: the form renders f.collection_select :user_id, so each model needs a user_id.
  test "admin can create a bee hive assigned to a user" do
    admin = sign_in_admin
    assert_difference -> { BeeHive.count }, 1 do
      post admin_bee_hives_path, params: {
        bee_hive: { name: "Garden Hive", address: "Ann Arbor, MI", user_id: admin.id }
      }
    end
    assert_equal admin, BeeHive.order(:created_at).last.user
  end

  # The edit form submits the full bee_hive params; updating must apply them
  # (status, name, address, ...), not just pin_color/pin_icon — otherwise
  # publishing a hive via the form silently no-ops and it never hits the map.
  test "admin edit form updates a bee hive's status and fields" do
    sign_in_admin
    hive = BeeHive.create!(name: "Old Name", address: "Ann Arbor, MI", status: :pending)
    patch admin_bee_hive_path(hive), params: {
      bee_hive: { name: "New Name", address: "Ann Arbor, MI", status: "published" }
    }
    hive.reload
    assert_equal "published", hive.status, "status change from the edit form must persist"
    assert_equal "New Name", hive.name, "field edits from the edit form must persist"
  end

  # The moderation buttons (Approve/Reject) post status without a bee_hive key.
  test "admin moderation button publishes a bee hive" do
    sign_in_admin
    hive = BeeHive.create!(name: "Hive", address: "Ann Arbor, MI", status: :pending)
    patch admin_bee_hive_path(hive), params: { status: :published }
    assert_equal "published", hive.reload.status
  end

  test "admin can create a tribute assigned to a user" do
    admin = sign_in_admin
    assert_difference -> { Tribute.count }, 1 do
      post admin_tributes_path, params: {
        tribute: { name: "A Friend", content: "He was wonderful.", user_id: admin.id }
      }
    end
    assert_equal admin, Tribute.order(:created_at).last.user
  end

  test "admin can create a tree assigned to a user" do
    admin = sign_in_admin
    assert_difference -> { Tree.count }, 1 do
      post admin_trees_path, params: {
        tree: { name: "Oak", address: "Ann Arbor, MI", tree_count: 1, user_id: admin.id }
      }
    end
    assert_equal admin, Tree.order(:created_at).last.user
  end

  test "admin can create a recipe assigned to a user" do
    admin = sign_in_admin
    assert_difference -> { Recipe.count }, 1 do
      post admin_recipes_path, params: {
        recipe: { submitter_name: "Cook", title: "Soup", ingredients: "Water",
                  instructions: "Boil", user_id: admin.id }
      }
    end
    assert_equal admin, Recipe.order(:created_at).last.user
  end
end
