class AddVideoUrlToTributes < ActiveRecord::Migration[8.1]
  def change
    add_column :tributes, :video_url, :string
    # A tribute may now be a video instead of written text, so content is optional.
    change_column_null :tributes, :content, true
  end
end
