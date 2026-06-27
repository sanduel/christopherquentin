require "test_helper"

class AdminTest < ActionDispatch::IntegrationTest
  include SignInHelper

  test "non-admin cannot access admin dashboard" do
    sign_in_contributor
    get admin_root_path
    assert_redirected_to root_path
  end

  test "admin can access dashboard" do
    sign_in_admin
    get admin_root_path
    assert_response :success
    assert_select "h1", "Dashboard"
  end

  test "admin can approve a tribute" do
    sign_in_admin
    tribute = Tribute.create!(name: "Test", content: "Content", status: :pending)

    patch admin_tribute_path(tribute), params: { status: :published }
    assert_redirected_to admin_tributes_path

    tribute.reload
    assert_equal "published", tribute.status
  end

  test "admin can reject a tribute" do
    sign_in_admin
    tribute = Tribute.create!(name: "Test", content: "Content", status: :pending)

    patch admin_tribute_path(tribute), params: { status: :rejected }
    tribute.reload
    assert_equal "rejected", tribute.status
  end

  test "non-admin cannot access admin events" do
    sign_in_contributor
    get admin_events_path
    assert_redirected_to root_path
  end

  test "admin can create an event" do
    sign_in_admin
    assert_difference -> { Event.count }, 1 do
      post admin_events_path, params: {
        event: {
          title: "Tribute Concert",
          event_type: "concert",
          starts_at: 5.days.from_now,
          published: "1"
        }
      }
    end
    assert_redirected_to admin_events_path
    event = Event.last
    assert_equal "Tribute Concert", event.title
    assert event.published?
  end

  test "admin can edit an event" do
    sign_in_admin
    event = Event.create!(title: "Old", event_type: :webinar, starts_at: 1.day.from_now)

    patch admin_event_path(event), params: { event: { title: "New Title" } }
    assert_redirected_to admin_events_path
    assert_equal "New Title", event.reload.title
  end

  test "admin can delete an event" do
    sign_in_admin
    event = Event.create!(title: "Doomed", event_type: :webinar, starts_at: 1.day.from_now)

    assert_difference -> { Event.count }, -1 do
      delete admin_event_path(event)
    end
    assert_redirected_to admin_events_path
  end

  test "admin can approve a bee hive" do
    sign_in_admin
    hive = BeeHive.create!(name: "Garden hive", address: "Ann Arbor, MI")

    patch admin_bee_hive_path(hive), params: { status: :published }
    assert_redirected_to admin_bee_hives_path
    assert_equal "published", hive.reload.status
  end

  test "admin can override a tree's pin color and icon" do
    sign_in_admin
    tree = Tree.create!(name: "Cabin tree", address: "Ann Arbor, MI", tree_count: 1, status: :published)

    patch admin_tree_path(tree), params: { tree: { pin_color: "#ff00ff", pin_icon: "fire" } }
    assert_redirected_to admin_trees_path
    tree.reload
    assert_equal "#ff00ff", tree.pin_color
    assert_equal "fire", tree.pin_icon
  end

  test "admin can clear a tree pin override (use defaults)" do
    sign_in_admin
    tree = Tree.create!(name: "Cabin tree", address: "Ann Arbor, MI", tree_count: 1, status: :published, pin_color: "#ff00ff", pin_icon: "fire")

    patch admin_tree_path(tree), params: { tree: { pin_color: "", pin_icon: "" } }
    tree.reload
    assert_equal "", tree.pin_color
    assert_equal "", tree.pin_icon
    assert_equal Tree.default_pin_color, tree.effective_pin_color
    assert_equal Tree.default_pin_icon, tree.effective_pin_icon
  end

  # new/create: trees
  test "admin can visit new tree page" do
    sign_in_admin
    get new_admin_tree_path
    assert_response :success
    assert_select "h1", "New Tree"
  end

  test "admin can create a tree" do
    sign_in_admin
    assert_difference -> { Tree.count }, 1 do
      post admin_trees_path, params: {
        tree: { name: "Oak Grove", address: "Ann Arbor, MI", tree_count: 3, story: "A lovely grove" }
      }
    end
    assert_redirected_to admin_trees_path
    tree = Tree.last
    assert_equal "Oak Grove", tree.name
    assert_equal "published", tree.status
  end

  test "admin can create a tree and assign to user" do
    sign_in_admin
    user = User.create!(name: "Jane", email: "jane@test.com", password: "password123", role: :contributor)
    assert_difference -> { Tree.count }, 1 do
      post admin_trees_path, params: {
        tree: { name: "Jane's Tree", address: "Ann Arbor, MI", tree_count: 1, user_id: user.id }
      }
    end
    assert_equal user, Tree.last.user
  end

  # new/create: tributes
  test "admin can visit new tribute page" do
    sign_in_admin
    get new_admin_tribute_path
    assert_response :success
    assert_select "h1", "New Tribute"
  end

  test "admin can create a tribute" do
    sign_in_admin
    assert_difference -> { Tribute.count }, 1 do
      post admin_tributes_path, params: {
        tribute: { name: "Mary Smith", content: "A wonderful person.", relationship: "Friend" }
      }
    end
    assert_redirected_to admin_tributes_path
    assert_equal "published", Tribute.last.status
  end

  # new/create: memories
  test "admin can visit new memory page" do
    sign_in_admin
    get new_admin_memory_path
    assert_response :success
    assert_select "h1", "New Memory"
  end

  test "admin can create a memory with user assigned" do
    sign_in_admin
    user = User.create!(name: "Bob", email: "bob@test.com", password: "password123", role: :contributor)
    assert_difference -> { Memory.count }, 1 do
      post admin_memories_path, params: {
        memory: {
          date: "2024-06-01",
          kind: "text",
          content: "A great memory.",
          user_id: user.id
        }
      }
    end
    assert_redirected_to admin_memories_path
    memory = Memory.last
    assert_equal "published", memory.status
    assert_equal user, memory.user
  end

  # new/create: recipes
  test "admin can visit new recipe page" do
    sign_in_admin
    get new_admin_recipe_path
    assert_response :success
    assert_select "h1", "New Recipe"
  end

  test "admin can create a recipe" do
    sign_in_admin
    assert_difference -> { Recipe.count }, 1 do
      post admin_recipes_path, params: {
        recipe: {
          title: "Honey Cake",
          submitter_name: "Admin",
          ingredients: "Honey, flour, eggs",
          instructions: "Mix and bake."
        }
      }
    end
    assert_redirected_to admin_recipes_path
    assert_equal "published", Recipe.last.status
  end

  # new/create: bee_hives
  test "admin can visit new bee hive page" do
    sign_in_admin
    get new_admin_bee_hive_path
    assert_response :success
    assert_select "h1", "New Bee Hive"
  end

  test "admin can create a bee hive" do
    sign_in_admin
    assert_difference -> { BeeHive.count }, 1 do
      post admin_bee_hives_path, params: {
        bee_hive: { name: "Garden Hive", address: "Ann Arbor, MI" }
      }
    end
    assert_redirected_to admin_bee_hives_path
    assert_equal "published", BeeHive.last.status
  end
end
