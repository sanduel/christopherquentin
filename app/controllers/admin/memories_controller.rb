class Admin::MemoriesController < Admin::BaseController
  before_action :set_memory, only: [ :show, :edit, :update, :destroy ]

  def index
    @memories = Memory.order(created_at: :desc)
    @memories = @memories.where(status: params[:status]) if params[:status].present?
  end

  def show
  end

  def edit
  end

  def update
    if memory_params_present?
      if @memory.update(memory_params)
        redirect_to admin_memories_path, notice: "Memory updated."
      else
        render :edit, status: :unprocessable_entity
      end
    else
      @memory.update!(status: params[:status])
      redirect_to admin_memories_path, notice: "Memory #{params[:status]}."
    end
  end

  def destroy
    @memory.destroy
    redirect_to admin_memories_path, notice: "Memory deleted."
  end

  private

  def set_memory
    @memory = Memory.find(params[:id])
  end

  def memory_params
    params.require(:memory).permit(
      :date, :title, :content, :location,
      :name, :relationship, :email,
      :kind, :audio_label, :audio_length,
      :pin_color, :pin_icon,
      :audio_clip, photos: []
    )
  end

  def memory_params_present?
    params[:memory].present?
  end
end
