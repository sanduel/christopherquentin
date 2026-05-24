class AddPinFieldsToTrees < ActiveRecord::Migration[8.1]
  def change
    add_column :trees, :pin_color, :string
    add_column :trees, :pin_icon, :string
  end
end
