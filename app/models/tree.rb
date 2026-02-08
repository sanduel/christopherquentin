class Tree < ApplicationRecord
  enum :status, { pending: 0, published: 1, rejected: 2 }

  has_one_attached :photo

  geocoded_by :address
  after_validation :geocode, if: ->(t) { t.address_changed? && t.address.present? }

  validates :name, :address, presence: true
  validates :tree_count, numericality: { greater_than: 0 }
end
