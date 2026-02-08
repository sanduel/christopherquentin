class Memory < ApplicationRecord
  enum :status, { pending: 0, published: 1, rejected: 2 }

  belongs_to :user, optional: true
  has_many_attached :photos

  validates :date, presence: true
  validates :content, presence: true, unless: -> { photos.attached? }
end
