class BeeHivesController < ApplicationController
  def index
    @bee_hives = BeeHive.published.order(created_at: :desc)
  end

  def show
    @bee_hive = BeeHive.published.find(params[:id])
  end

  def new
    @bee_hive = BeeHive.new
  end

  def create
    @bee_hive = BeeHive.new(bee_hive_params)
    @bee_hive.status = :pending

    if @bee_hive.save
      redirect_to bee_hives_path, notice: "Thank you! Your bee hive will appear on the map after review."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def bee_hive_params
    params.require(:bee_hive).permit(:name, :email, :address, :story, :photo)
  end
end
