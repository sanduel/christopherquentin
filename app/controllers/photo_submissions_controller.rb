class PhotoSubmissionsController < ApplicationController
  def new
    @photo_submission = PhotoSubmission.new
  end

  def create
    @photo_submission = PhotoSubmission.new(photo_submission_params)
    @photo_submission.status = :pending

    if @photo_submission.save
      redirect_to root_path, notice: "Thank you for submitting photos. They will be reviewed shortly."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def photo_submission_params
    params.require(:photo_submission).permit(:name, :email, photos: [])
  end
end
