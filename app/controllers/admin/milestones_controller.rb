class Admin::MilestonesController < Admin::BaseController
  before_action :set_milestone, only: [ :edit, :update, :destroy ]

  def index
    @milestones = Milestone.chronological
  end

  def new
    @milestone = Milestone.new
  end

  def create
    @milestone = Milestone.new(milestone_params)
    if @milestone.save
      redirect_to admin_milestones_path, notice: "Milestone created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @milestone.update(milestone_params)
      redirect_to admin_milestones_path, notice: "Milestone updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @milestone.destroy
    redirect_to admin_milestones_path, notice: "Milestone deleted."
  end

  private

  def set_milestone
    @milestone = Milestone.find(params[:id])
  end

  def milestone_params
    params.require(:milestone).permit(:date, :headline, :description, :icon, :location)
  end
end
