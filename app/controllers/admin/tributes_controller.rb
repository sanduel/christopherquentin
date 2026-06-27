class Admin::TributesController < Admin::BaseController
  before_action :set_tribute, only: [ :show, :edit, :update, :destroy ]

  def index
    @tributes = Tribute.order(created_at: :desc)
    @tributes = @tributes.where(status: params[:status].to_sym) if params[:status].present? && Tribute.statuses.key?(params[:status])
  end

  def show
  end

  def new
    @tribute = Tribute.new
  end

  def create
    @tribute = Tribute.new(tribute_params)
    @tribute.status = :published unless params[:tribute]&.key?(:status)

    if @tribute.save
      redirect_to admin_tributes_path, notice: "Tribute created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if tribute_params_present?
      if @tribute.update(tribute_params)
        redirect_to admin_tributes_path, notice: "Tribute updated."
      else
        render :edit, status: :unprocessable_entity
      end
    else
      @tribute.update!(status: params[:status])
      redirect_to admin_tributes_path, notice: "Tribute #{params[:status]}."
    end
  end

  def destroy
    @tribute.destroy
    redirect_to admin_tributes_path, notice: "Tribute deleted."
  end

  private

  def set_tribute
    @tribute = Tribute.find(params[:id])
  end

  def tribute_params
    params.require(:tribute).permit(:name, :relationship, :content, :category, :photo, :user_id, :status)
  end

  def tribute_params_present?
    params[:tribute].present?
  end
end
