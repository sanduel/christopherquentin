class Admin::RecipesController < Admin::BaseController
  before_action :set_recipe, only: [ :show, :edit, :update, :destroy ]

  def index
    @recipes = Recipe.order(created_at: :desc)
    @recipes = @recipes.where(status: params[:status].to_sym) if params[:status].present? && Recipe.statuses.key?(params[:status])
  end

  def show
  end

  def edit
  end

  def update
    if recipe_params_present?
      if @recipe.update(recipe_params)
        redirect_to admin_recipes_path, notice: "Recipe updated."
      else
        render :edit, status: :unprocessable_entity
      end
    else
      @recipe.update!(status: params[:status])
      redirect_to admin_recipes_path, notice: "Recipe #{params[:status]}."
    end
  end

  def destroy
    @recipe.destroy
    redirect_to admin_recipes_path, notice: "Recipe deleted."
  end

  private

  def set_recipe
    @recipe = Recipe.find(params[:id])
  end

  def recipe_params
    params.require(:recipe).permit(:submitter_name, :title, :ingredients, :instructions, :photo)
  end

  def recipe_params_present?
    params[:recipe].present?
  end
end
