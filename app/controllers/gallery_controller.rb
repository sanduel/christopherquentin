class GalleryController < ApplicationController
  PER_PAGE = 48

  def index
    @page = [ params[:page].to_i, 1 ].max
    scope = GalleryPhoto.published.with_attached_photo
    @total = scope.count
    @total_pages = [ (@total.to_f / PER_PAGE).ceil, 1 ].max
    @photos = scope.limit(PER_PAGE).offset((@page - 1) * PER_PAGE)
  end

  def new
    @submitter_name = nil
    @submitter_email = nil
  end

  def create
    @submitter_name = params[:submitter_name].to_s.strip
    @submitter_email = params[:submitter_email].to_s.strip
    files = Array(params[:photos]).reject(&:blank?)

    if @submitter_name.blank? || @submitter_email.blank? || files.empty?
      flash.now[:alert] = "Please add your name, email, and at least one photo."
      return render :new, status: :unprocessable_entity
    end

    saved = files.map { |file| create_pending_photo(file) }.count(&:itself)

    if saved.positive?
      redirect_to root_path, notice: "Thank you! Your #{'photo'.pluralize(saved)} will appear in the gallery after review."
    else
      flash.now[:alert] = "Sorry, those files couldn't be uploaded. Please try again."
      render :new, status: :unprocessable_entity
    end
  end

  private

  def create_pending_photo(file)
    photo = GalleryPhoto.new(status: :pending, submitter_name: @submitter_name, submitter_email: @submitter_email)
    photo.photo.attach(file)
    photo.save
  end
end
