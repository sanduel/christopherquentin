class Admin::GalleryPhotosController < Admin::BaseController
  before_action :set_photo, only: [ :edit, :update, :destroy ]

  PER_PAGE = 60

  def index
    @page = [ params[:page].to_i, 1 ].max
    scope = GalleryPhoto.with_attached_photo
    scope = scope.where(status: params[:status]) if params[:status].present? && GalleryPhoto.statuses.key?(params[:status])
    @total = scope.count
    @total_pages = [ (@total.to_f / PER_PAGE).ceil, 1 ].max
    @photos = scope.limit(PER_PAGE).offset((@page - 1) * PER_PAGE)
  end

  def new
    @photo = GalleryPhoto.new
  end

  def create
    @photo = GalleryPhoto.new(gallery_photo_params)
    if @photo.save
      redirect_to admin_gallery_photos_path, notice: "Photo added to gallery."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if params[:gallery_photo].present?
      if @photo.update(gallery_photo_params)
        redirect_to admin_gallery_photos_path, notice: "Photo updated."
      else
        render :edit, status: :unprocessable_entity
      end
    elsif params.key?(:featured)
      @photo.update!(featured: ActiveModel::Type::Boolean.new.cast(params[:featured]))
      redirect_back fallback_location: admin_gallery_photos_path, notice: (@photo.featured? ? "Marked as featured." : "Removed from featured.")
    elsif params.key?(:bio_grid)
      @photo.update!(bio_grid: ActiveModel::Type::Boolean.new.cast(params[:bio_grid]))
      redirect_back fallback_location: admin_gallery_photos_path, notice: (@photo.bio_grid? ? "Added to bio grid." : "Removed from bio grid.")
    else
      @photo.update!(status: params[:status])
      redirect_back fallback_location: admin_gallery_photos_path, notice: "Photo #{params[:status]}."
    end
  end

  def destroy
    @photo.destroy
    redirect_to admin_gallery_photos_path, notice: "Photo removed."
  end

  private

  def set_photo
    @photo = GalleryPhoto.find(params[:id])
  end

  def gallery_photo_params
    params.require(:gallery_photo).permit(:photo, :caption, :sort_order, :status, :featured, :bio_grid, :submitter_name, :submitter_email)
  end
end
