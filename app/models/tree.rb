class Tree < ApplicationRecord
  include Mappable

  enum :status, { pending: 0, published: 1, rejected: 2 }

  has_one_attached :photo

  geocoded_by :address
  after_validation :geocode, if: ->(t) { t.address_changed? && t.address.present? && t.latitude.blank? }

  validates :name, :address, presence: true
  validates :tree_count, numericality: { greater_than: 0 }

  def self.default_pin_color = "#16a34a"      # green-600
  def self.default_pin_icon  = "tree-pine"
  def self.map_category      = :tree
end
