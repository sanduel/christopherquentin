class CreatePhotoSubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :photo_submissions do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.integer :status, null: false, default: 0

      t.timestamps
    end
  end
end
