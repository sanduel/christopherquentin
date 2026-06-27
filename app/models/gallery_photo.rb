class GalleryPhoto < ApplicationRecord
  enum :status, { pending: 0, published: 1, rejected: 2 }

  has_one_attached :photo

  validates :photo, presence: true

  scope :featured, -> { where(featured: true) }
  scope :newest_first, -> { reorder(created_at: :desc) }

  default_scope { order(:sort_order) }

  def submitted?
    submitter_name.present? || submitter_email.present?
  end
end
