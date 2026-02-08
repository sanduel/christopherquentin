class CreateRecipes < ActiveRecord::Migration[8.1]
  def change
    create_table :recipes do |t|
      t.string :submitter_name, null: false
      t.string :title, null: false
      t.text :ingredients
      t.text :instructions
      t.text :story
      t.integer :status, null: false, default: 0

      t.timestamps
    end
  end
end
