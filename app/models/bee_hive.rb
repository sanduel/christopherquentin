class BeeHive < ApplicationRecord
  include Mappable

  enum :status, { pending: 0, published: 1, rejected: 2 }

  belongs_to :user, optional: true
  has_one_attached :photo

  geocoded_by :address
  after_validation :geocode, if: ->(h) { h.address_changed? && h.address.present? && h.latitude.blank? }

  validates :name, :address, presence: true

  def self.default_pin_color = "#ca8a04"      # yellow-600
  def self.default_pin_icon  = "hexagon"
  def self.map_category      = :bee_hive
end
