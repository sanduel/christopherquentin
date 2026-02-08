class CreateGalleryPhotos < ActiveRecord::Migration[8.1]
  def change
    create_table :gallery_photos do |t|
      t.string :caption
      t.integer :sort_order, default: 0

      t.timestamps
    end
  end
end
