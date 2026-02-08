class CreateTrees < ActiveRecord::Migration[8.1]
  def change
    create_table :trees do |t|
      t.string :name, null: false
      t.string :email
      t.string :address, null: false
      t.float :latitude
      t.float :longitude
      t.integer :tree_count, default: 1
      t.text :story
      t.integer :status, null: false, default: 0

      t.timestamps
    end
  end
end
