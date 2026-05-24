class RecipesController < ApplicationController
  def index
    @recipes = Recipe.published.order(created_at: :desc)
  end

  def show
    @recipe = Recipe.published.find(params[:id])
  end

  def new
    @recipe = Recipe.new
  end

  def create
    @recipe = Recipe.new(recipe_params)
    @recipe.status = :pending

    if @recipe.save
      redirect_to recipes_path, notice: "Thank you for sharing this recipe. It will appear after review."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def recipe_params
    params.require(:recipe).permit(:submitter_name, :title, :ingredients, :instructions, :story, :photo)
  end
end
