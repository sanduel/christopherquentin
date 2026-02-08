class GalleryPhoto < ApplicationRecord
  has_one_attached :photo

  validates :photo, presence: true

  default_scope { order(:sort_order) }
end
