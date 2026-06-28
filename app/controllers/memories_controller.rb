class MemoriesController < ApplicationController
  def index
    load_timeline_locals
  end

  def show
    @memory = Memory.published.find(params[:id])
  end

  def new
    @memory = Memory.new(kind: :text, date: Date.today)
    load_timeline_locals
  end

  def create
    @memory = Memory.new(memory_params)
    @memory.user = current_user if user_signed_in?
    @memory.status = user_signed_in? ? :published : :pending
    @memory.name = current_user.name if user_signed_in? && @memory.name.blank?

    if @memory.save
      msg = user_signed_in? ?
        "Memory shared — it's live on the timeline now." :
        "Thank you. Your memory is queued for review and will appear on the timeline once approved."
      redirect_to memories_path, notice: msg
    else
      load_timeline_locals
      flash.now[:alert] = @memory.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  private

  def load_timeline_locals
    @active_year = params[:year]&.to_i

    memory_scope    = Memory.published.includes(:user, :replies).order(date: :desc)
    milestone_scope = Milestone.all

    if @active_year
      range = Date.new(@active_year, 1, 1)..Date.new(@active_year, 12, 31)
      memory_scope    = memory_scope.where(date: range)
      milestone_scope = milestone_scope.where(date: range)
    end

    @memories         = memory_scope
    @timeline_by_year = build_timeline_by_year(@memories, milestone_scope)
    @years            = (Memory.published.pluck(:date) + Milestone.pluck(:date))
                          .map(&:year).uniq.sort.reverse

    @memories_count = @memories.count
    @contributors_count = User.joins(:memories).merge(Memory.published).distinct.count +
                          Memory.published.where(user_id: nil).where.not(email: nil).select(:email).distinct.count
  end

  def build_timeline_by_year(memories, milestones)
    (memories.to_a + milestones.to_a).sort_by(&:date).reverse.group_by(&:year)
  end

  def memory_params
    params.require(:memory).permit(
      :date, :title, :content, :location, :video_url,
      :name, :relationship, :email,
      :kind, :audio_label, :audio_length,
      :audio_clip,
      photos: []
    )
  end
end
