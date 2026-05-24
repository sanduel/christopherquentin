class TributesController < ApplicationController
  def index
    @tributes = Tribute.published.order(created_at: :desc)
  end

  def show
    @tribute = Tribute.published.find(params[:id])
  end

  def new
    @tribute = Tribute.new
  end

  def create
    @tribute = Tribute.new(tribute_params)
    @tribute.status = :pending

    if @tribute.save
      redirect_to tributes_path, notice: "Thank you for your tribute. It will appear after review."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def tribute_params
    params.require(:tribute).permit(:name, :relationship, :content, :photo)
  end
end
