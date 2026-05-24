class AddMapFieldsToMemories < ActiveRecord::Migration[8.1]
  def change
    add_column :memories, :location, :string
    add_column :memories, :latitude, :float
    add_column :memories, :longitude, :float
    add_column :memories, :pin_color, :string
    add_column :memories, :pin_icon, :string
  end
end
