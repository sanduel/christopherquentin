class Admin::TributesController < Admin::BaseController
  before_action :set_tribute, only: [ :show, :update, :destroy ]

  def index
    @tributes = Tribute.order(created_at: :desc)
    @tributes = @tributes.where(status: params[:status]) if params[:status].present?
  end

  def show
  end

  def update
    @tribute.update!(status: params[:status])
    redirect_to admin_tributes_path, notice: "Tribute #{params[:status]}."
  end

  def destroy
    @tribute.destroy
    redirect_to admin_tributes_path, notice: "Tribute deleted."
  end

  private

  def set_tribute
    @tribute = Tribute.find(params[:id])
  end
end
