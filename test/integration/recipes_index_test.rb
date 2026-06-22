require "test_helper"

class RecipesIndexTest < ActionDispatch::IntegrationTest
  def setup
    Recipe.delete_all
    Recipe.create!(
      submitter_name: "Aunt Margaret",
      title: "Chris's Cape Cod Clam Chowder",
      ingredients: "Clams, potatoes, onions, cream",
      instructions: "Simmer.",
      status: :published
    )
    Recipe.create!(
      submitter_name: "Sigrid",
      title: "Norwegian Cinnamon Buns",
      ingredients: "Flour, butter, cinnamon, cardamom",
      instructions: "Knead.",
      status: :published
    )
  end

  test "renders header" do
    get recipes_path
    assert_response :success
    assert_select ".text-eyebrow", text: /Op\. VIII · Recipes/
    assert_select "h1.font-serif", text: /cooked/i
  end

  test "renders one recipe card per published recipe" do
    get recipes_path
    assert_select "[data-recipe-card]", count: 2
  end

  test "recipe card shows title, attribution, link" do
    get recipes_path
    assert_select "[data-recipe-card]" do
      assert_select "h3", text: /Cape Cod Clam Chowder/
      assert_select "*", text: /from Aunt Margaret/
    end
  end

  test "submit a recipe CTA links to new_recipe_path" do
    get recipes_path
    assert_select "a[href=?]", new_recipe_path, text: /Submit a recipe/i
  end

  test "Recipe show page renders without crashing" do
    recipe = Recipe.first
    get recipe_path(recipe)
    assert_response :success
    assert_select "h1.font-serif", text: /#{recipe.title}/
  end
end
