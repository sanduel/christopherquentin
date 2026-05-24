class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.string :title, null: false
      t.text :description
      t.integer :event_type, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at
      t.string :location
      t.string :url
      t.boolean :published, null: false, default: false

      t.timestamps
    end

    add_index :events, :starts_at
    add_index :events, [ :published, :starts_at ]
  end
end
