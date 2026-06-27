class Admin::BeeHivesController < Admin::BaseController
  before_action :set_bee_hive, only: [ :show, :edit, :update, :destroy ]

  def index
    @bee_hives = BeeHive.order(created_at: :desc)
    @bee_hives = @bee_hives.where(status: params[:status]) if params[:status].present?
  end

  def show
  end

  def new
    @bee_hive = BeeHive.new
  end

  def create
    @bee_hive = BeeHive.new(bee_hive_params)
    @bee_hive.status = :published unless params[:bee_hive]&.key?(:status)

    if @bee_hive.save
      redirect_to admin_bee_hives_path, notice: "Bee hive created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if pin_params_present?
      if @bee_hive.update(pin_params)
        redirect_to admin_bee_hives_path, notice: "Hive pin updated."
      else
        render :edit, status: :unprocessable_entity
      end
    else
      @bee_hive.update!(status: params[:status])
      redirect_to admin_bee_hives_path, notice: "Hive #{params[:status]}."
    end
  end

  def destroy
    @bee_hive.destroy
    redirect_to admin_bee_hives_path, notice: "Hive deleted."
  end

  private

  def set_bee_hive
    @bee_hive = BeeHive.find(params[:id])
  end

  def bee_hive_params
    params.require(:bee_hive).permit(:name, :email, :address, :story, :photo,
                                     :pin_color, :pin_icon, :user_id, :status)
  end

  def pin_params
    params.require(:bee_hive).permit(:pin_color, :pin_icon)
  end

  def pin_params_present?
    params[:bee_hive].present?
  end
end
