class Admin::PhotoSubmissionsController < Admin::BaseController
  before_action :set_submission, only: [ :show, :update, :destroy ]

  def index
    @submissions = PhotoSubmission.order(created_at: :desc)
    @submissions = @submissions.where(status: params[:status].to_sym) if params[:status].present? && PhotoSubmission.statuses.key?(params[:status])
  end

  def show
  end

  def update
    @submission.update!(status: params[:status])
    redirect_to admin_photo_submissions_path, notice: "Photo submission #{params[:status]}."
  end

  def destroy
    @submission.destroy
    redirect_to admin_photo_submissions_path, notice: "Photo submission deleted."
  end

  private

  def set_submission
    @submission = PhotoSubmission.find(params[:id])
  end
end
