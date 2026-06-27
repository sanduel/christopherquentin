class Admin::TreesController < Admin::BaseController
  before_action :set_tree, only: [ :show, :edit, :update, :destroy ]

  def index
    @trees = Tree.order(created_at: :desc)
    @trees = @trees.where(status: params[:status]) if params[:status].present?
  end

  def show
  end

  def new
    @tree = Tree.new
  end

  def create
    @tree = Tree.new(tree_params)
    @tree.status = :published unless params[:tree]&.key?(:status)

    if @tree.save
      redirect_to admin_trees_path, notice: "Tree created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if tree_params_present?
      if @tree.update(tree_params)
        redirect_to admin_trees_path, notice: "Tree updated."
      else
        render :edit, status: :unprocessable_entity
      end
    else
      @tree.update!(status: params[:status])
      redirect_to admin_trees_path, notice: "Tree #{params[:status]}."
    end
  end

  def destroy
    @tree.destroy
    redirect_to admin_trees_path, notice: "Tree deleted."
  end

  private

  def set_tree
    @tree = Tree.find(params[:id])
  end

  def tree_params
    params.require(:tree).permit(
      :name, :email, :address, :tree_count, :story,
      :pin_color, :pin_icon, :photo,
      :user_id, :status
    )
  end

  def tree_params_present?
    params[:tree].present?
  end
end
