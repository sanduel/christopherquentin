class AddBioGridToGalleryPhotos < ActiveRecord::Migration[8.1]
  def change
    add_column :gallery_photos, :bio_grid, :boolean, default: false, null: false
    add_index :gallery_photos, :bio_grid
  end
end
