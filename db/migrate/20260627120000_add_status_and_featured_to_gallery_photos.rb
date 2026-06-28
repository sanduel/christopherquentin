class AddStatusAndFeaturedToGalleryPhotos < ActiveRecord::Migration[8.1]
  def change
    # Existing/admin-added photos default to published; visitor submissions
    # are explicitly created as pending for review.
    add_column :gallery_photos, :status, :integer, default: 1, null: false
    add_column :gallery_photos, :featured, :boolean, default: false, null: false
    add_column :gallery_photos, :submitter_name, :string
    add_column :gallery_photos, :submitter_email, :string

    add_index :gallery_photos, :status
    add_index :gallery_photos, :featured
  end
end
