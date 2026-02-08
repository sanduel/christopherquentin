class CreateMemories < ActiveRecord::Migration[8.1]
  def change
    create_table :memories do |t|
      t.references :user, foreign_key: true
      t.date :date, null: false
      t.string :title
      t.text :content
      t.integer :status, null: false, default: 0

      t.timestamps
    end
  end
end
