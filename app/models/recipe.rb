class Recipe < ApplicationRecord
  enum :status, { pending: 0, published: 1, rejected: 2 }

  has_one_attached :photo

  validates :submitter_name, :title, :ingredients, :instructions, presence: true
end
