class AddUserToTributesTreesRecipesBeeHives < ActiveRecord::Migration[8.1]
  def change
    add_reference :tributes,  :user, foreign_key: true, index: true
    add_reference :trees,     :user, foreign_key: true, index: true
    add_reference :recipes,   :user, foreign_key: true, index: true
    add_reference :bee_hives, :user, foreign_key: true, index: true
  end
end
