class AddVideoUrlToMemories < ActiveRecord::Migration[8.1]
  def change
    add_column :memories, :video_url, :string
  end
end
