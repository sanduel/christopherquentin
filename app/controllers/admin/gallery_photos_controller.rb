class Admin::GalleryPhotosController < Admin::BaseController
  before_action :set_photo, only: [ :edit, :update, :destroy ]

  PER_PAGE = 60

  def index
    @page = [ params[:page].to_i, 1 ].max
    scope = GalleryPhoto.with_attached_photo
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
    if @photo.update(gallery_photo_params)
      redirect_to admin_gallery_photos_path, notice: "Photo updated."
    else
      render :edit, status: :unprocessable_entity
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
    params.require(:gallery_photo).permit(:photo, :caption, :sort_order)
  end
end
