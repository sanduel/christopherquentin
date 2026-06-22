class Tribute < ApplicationRecord
  enum :status, { pending: 0, published: 1, rejected: 2 }
  enum :category, { family: 0, colleagues: 1, musicians: 2, students: 3, friends: 4 }, prefix: :category

  has_one_attached :photo

  validates :name, :content, presence: true
end
