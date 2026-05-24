class Admin::TreesController < Admin::BaseController
  before_action :set_tree, only: [ :show, :edit, :update, :destroy ]

  def index
    @trees = Tree.order(created_at: :desc)
    @trees = @trees.where(status: params[:status]) if params[:status].present?
  end

  def show
  end

  def edit
  end

  def update
    if pin_params_present?
      if @tree.update(pin_params)
        redirect_to admin_trees_path, notice: "Tree pin updated."
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

  def pin_params
    params.require(:tree).permit(:pin_color, :pin_icon)
  end

  def pin_params_present?
    params[:tree].present?
  end
end
