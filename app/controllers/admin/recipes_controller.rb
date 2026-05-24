class Admin::RecipesController < Admin::BaseController
  before_action :set_recipe, only: [ :show, :update, :destroy ]

  def index
    @recipes = Recipe.order(created_at: :desc)
    @recipes = @recipes.where(status: params[:status]) if params[:status].present?
  end

  def show
  end

  def update
    @recipe.update!(status: params[:status])
    redirect_to admin_recipes_path, notice: "Recipe #{params[:status]}."
  end

  def destroy
    @recipe.destroy
    redirect_to admin_recipes_path, notice: "Recipe deleted."
  end

  private

  def set_recipe
    @recipe = Recipe.find(params[:id])
  end
end
