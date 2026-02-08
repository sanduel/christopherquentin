class CreateTributes < ActiveRecord::Migration[8.1]
  def change
    create_table :tributes do |t|
      t.string :name, null: false
      t.string :relationship
      t.text :content, null: false
      t.integer :status, null: false, default: 0

      t.timestamps
    end
  end
end
