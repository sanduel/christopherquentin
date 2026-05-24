class MemoriesController < ApplicationController
  before_action :authenticate_user!, only: [ :new, :create ]

  def index
    @memories = Memory.published.order(date: :desc)
  end

  def show
    @memory = Memory.published.find(params[:id])
  end

  def new
    @memory = Memory.new
  end

  def create
    @memory = Memory.new(memory_params)
    @memory.user = current_user
    @memory.status = :pending

    if @memory.save
      redirect_to memories_path, notice: "Thank you for sharing this memory. It will appear on the timeline after review."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def memory_params
    params.require(:memory).permit(:date, :title, :content, :location, photos: [])
  end
end
