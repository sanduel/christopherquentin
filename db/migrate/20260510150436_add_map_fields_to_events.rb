class AddMapFieldsToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :latitude, :float
    add_column :events, :longitude, :float
    add_column :events, :pin_color, :string
    add_column :events, :pin_icon, :string
  end
end
