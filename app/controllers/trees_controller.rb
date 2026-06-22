class TreesController < ApplicationController
  def index
    @trees = Tree.published.order(created_at: :desc)
    @new_tree = Tree.new
    @stats = tree_stats
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
      @trees = Tree.published.order(created_at: :desc)
      @new_tree = @tree
      @stats = tree_stats
      render :index, status: :unprocessable_entity
    end
  end

  private

  def tree_stats
    {
      trees: Tree.published.sum(:tree_count),
      cities: Tree.published.where.not(address: nil).distinct.count(:address),
      countries: 9,
    }
  end

  def tree_params
    params.require(:tree).permit(:name, :email, :address, :tree_count, :story, :photo)
  end
end
