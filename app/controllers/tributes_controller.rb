class TributesController < ApplicationController
  def index
    scope = Tribute.published.order(created_at: :desc)
    requested = params[:category].presence
    @active_category = (requested if Tribute.categories.key?(requested.to_s))
    @tributes = @active_category ? scope.where(category: @active_category) : scope
    @categories = Tribute.categories.keys
    @total_count = Tribute.published.count
  end

  def show
    @tribute = Tribute.published.find(params[:id])
  end

  def new
    @tribute = Tribute.new(category: :friends)
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
    params.require(:tribute).permit(:name, :relationship, :content, :category, :photo, :video_url)
  end
end
