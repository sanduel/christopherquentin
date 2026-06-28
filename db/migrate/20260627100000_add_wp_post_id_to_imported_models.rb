class AddWpPostIdToImportedModels < ActiveRecord::Migration[8.1]
  def change
    add_column :tributes,       :wp_post_id, :bigint
    add_column :gallery_photos, :wp_post_id, :bigint
    add_column :events,         :wp_post_id, :bigint
    add_column :recipes,        :wp_post_id, :bigint

    add_index :tributes,       :wp_post_id, unique: true
    add_index :gallery_photos, :wp_post_id, unique: true
    add_index :events,         :wp_post_id, unique: true
    add_index :recipes,        :wp_post_id, unique: true
  end
end
