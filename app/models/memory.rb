class Memory < ApplicationRecord
  include Mappable

  enum :status, { pending: 0, published: 1, rejected: 2 }

  belongs_to :user, optional: true
  has_many_attached :photos

  geocoded_by :location
  after_validation :geocode, if: ->(m) { m.location_changed? && m.location.present? && m.latitude.blank? }

  validates :date, presence: true
  validates :content, presence: true, unless: -> { photos.attached? }

  def self.default_pin_color = "#d97706"      # amber-600
  def self.default_pin_icon  = "star"
  def self.map_category      = :memory
end
