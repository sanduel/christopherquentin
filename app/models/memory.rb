class Memory < ApplicationRecord
  CHRIS_BIRTH_YEAR = 1984

  include Mappable

  enum :status, { pending: 0, published: 1, rejected: 2 }
  enum :kind,   { text: 0, photo: 1, audio: 2 }, prefix: :kind

  belongs_to :user, optional: true
  has_many   :replies, -> { order(:created_at) }, dependent: :destroy
  has_many_attached :photos
  has_one_attached  :audio_clip

  geocoded_by :location
  after_validation :geocode, if: ->(m) { m.location_changed? && m.location.present? && m.latitude.blank? }

  validates :date,    presence: true
  validates :content, presence: true, unless: -> { kind_photo? || kind_audio? }
  validates :name,    presence: true, if: -> { user_id.blank? }
  validates :email,   presence: true, if: -> { user_id.blank? }
  validates :email,   format: { with: URI::MailTo::EMAIL_REGEXP, message: "is invalid" }, allow_blank: true
  validate  :audio_clip_required_if_kind_audio
  validate  :photos_required_if_kind_photo

  def year = date.year
  def age  = year - CHRIS_BIRTH_YEAR
  def display_name = name.presence || user&.name || "Anonymous"
  def display_relationship = relationship.presence

  def self.default_pin_color = "#e11d48"      # rose-600 — distinct from tree green on the map
  def self.default_pin_icon  = "star"
  def self.map_category      = :memory

  private

  def audio_clip_required_if_kind_audio
    return unless kind_audio?
    errors.add(:audio_clip, "is required for audio memories") unless audio_clip.attached?
  end

  def photos_required_if_kind_photo
    return unless kind_photo?
    errors.add(:photos, "is required for photo memories") unless photos.attached?
  end
end
