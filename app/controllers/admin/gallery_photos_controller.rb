class Admin::GalleryPhotosController < Admin::BaseController
  before_action :set_photo, only: [ :edit, :update, :destroy ]

  def index
    @photos = GalleryPhoto.all
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
