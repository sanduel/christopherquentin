class RepliesController < ApplicationController
  before_action :set_memory

  def create
    @reply = @memory.replies.build(reply_params)
    @reply.user = current_user if user_signed_in?
    @reply.status = user_signed_in? ? :published : :pending
    @reply.name = current_user.name if user_signed_in? && @reply.name.blank?

    if @reply.save
      redirect_to memory_path(@memory),
        notice: user_signed_in? ? "Reply posted." : "Thanks. Your reply will appear after review."
    else
      redirect_to memory_path(@memory),
        alert: @reply.errors.full_messages.join(", "),
        status: :see_other
    end
  end

  private

  def set_memory
    @memory = Memory.published.find(params[:memory_id])
  end

  def reply_params
    params.require(:reply).permit(:name, :relationship, :email, :body)
  end
end
