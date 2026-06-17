class MemoriesController < ApplicationController
  def index
    scope = Memory.published.includes(:user, :replies).order(date: :desc)
    @years = Memory.published.pluck(Arel.sql("strftime('%Y', date)")).uniq.sort.reverse.map(&:to_i)
    @active_year = params[:year]&.to_i
    @memories = @active_year ? scope.where("strftime('%Y', date) = ?", @active_year.to_s) : scope
    @memories_count = @memories.count
    @contributors_count = User.joins(:memories).distinct.count +
                          Memory.where(user_id: nil).where.not(email: nil).select(:email).distinct.count
  end

  def show
    @memory = Memory.published.find(params[:id])
  end

  def new
    @memory = Memory.new(kind: :text, date: Date.today)
    scope = Memory.published.includes(:user, :replies).order(date: :desc)
    @years = Memory.published.pluck(Arel.sql("strftime('%Y', date)")).uniq.sort.reverse.map(&:to_i)
    @active_year = nil
    @memories = scope
    @memories_count = scope.count
    @contributors_count = User.joins(:memories).distinct.count +
                          Memory.where(user_id: nil).where.not(email: nil).select(:email).distinct.count
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
      render :new, status: :unprocessable_entity
    end
  end

  private

  def memory_params
    params.require(:memory).permit(
      :date, :title, :content, :location,
      :name, :relationship, :email,
      :kind, :audio_label, :audio_length,
      :audio_clip,
      photos: []
    )
  end
end
