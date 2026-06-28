class AddPortraitToGalleryPhotos < ActiveRecord::Migration[8.1]
  def change
    add_column :gallery_photos, :portrait, :boolean, default: false, null: false
    add_index :gallery_photos, :portrait
  end
end
