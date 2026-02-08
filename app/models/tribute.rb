class Tribute < ApplicationRecord
  enum :status, { pending: 0, published: 1, rejected: 2 }

  has_one_attached :photo

  validates :name, :content, presence: true
end
