class CreateBeeHives < ActiveRecord::Migration[8.1]
  def change
    create_table :bee_hives do |t|
      t.string :name, null: false
      t.string :address, null: false
      t.string :email
      t.text :story
      t.float :latitude
      t.float :longitude
      t.integer :status, null: false, default: 0
      t.string :pin_color
      t.string :pin_icon

      t.timestamps
    end
  end
end
