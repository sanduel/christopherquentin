class Tribute < ApplicationRecord
  include YoutubeEmbeddable

  enum :status, { pending: 0, published: 1, rejected: 2 }
  enum :category, { family: 0, colleagues: 1, musicians: 2, students: 3, friends: 4 }, prefix: :category

  belongs_to :user, optional: true
  has_one_attached :photo

  validates :name, presence: true
  validate :content_or_video_present

  private

  def content_or_video_present
    return if content.present? || video_url.present?

    errors.add(:base, "Add a written tribute or a YouTube video.")
  end
end
