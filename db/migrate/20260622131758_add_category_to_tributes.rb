class AddCategoryToTributes < ActiveRecord::Migration[8.1]
  def change
    add_column :tributes, :category, :integer, default: 4, null: false
    add_index  :tributes, :category
  end
end
