class TreesController < ApplicationController
  def index
    @trees = Tree.published.order(created_at: :desc)
  end

  def show
    @tree = Tree.published.find(params[:id])
  end

  def new
    @tree = Tree.new
  end

  def create
    @tree = Tree.new(tree_params)
    @tree.status = :pending

    if @tree.save
      redirect_to trees_path, notice: "Thank you for planting a tree! It will appear on the map after review."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def tree_params
    params.require(:tree).permit(:name, :email, :address, :tree_count, :story, :photo)
  end
end
