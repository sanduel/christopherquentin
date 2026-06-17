class Phase3MemoryAndReplies < ActiveRecord::Migration[8.1]
  def change
    add_column :memories, :name,         :string
    add_column :memories, :relationship, :string
    add_column :memories, :email,        :string
    add_column :memories, :kind,         :integer, default: 0, null: false
    add_column :memories, :audio_label,  :string
    add_column :memories, :audio_length, :string

    add_index :memories, :kind

    create_table :replies do |t|
      t.references :memory, null: false, foreign_key: true, index: true
      t.references :user, foreign_key: true, index: true
      t.string  :name,         null: false
      t.string  :relationship
      t.string  :email
      t.text    :body,         null: false
      t.integer :status,       default: 0, null: false
      t.index   [:status, :created_at]
      t.timestamps
    end
  end
end
