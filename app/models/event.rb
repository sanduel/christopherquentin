class Event < ApplicationRecord
  include Mappable

  enum :event_type, { webinar: 0, concert: 1, service: 2 }

  has_one_attached :cover_image

  geocoded_by :location
  after_validation :geocode, if: ->(e) { e.location_changed? && e.location.present? && e.latitude.blank? }

  validates :title, presence: true
  validates :event_type, presence: true
  validates :starts_at, presence: true
  # Only enforce on new/changed URLs so editing other fields on a legacy row
  # with a non-conforming URL isn't blocked. Rendering is guarded separately
  # (see EventsHelper#safe_event_url) so pre-existing rows can't inject script.
  validates :url,
            format: { with: %r{\Ahttps?://\S+\z}, message: "must be a valid http or https URL" },
            allow_blank: true,
            if: -> { will_save_change_to_url? }
  validate :ends_at_after_starts_at

  scope :published, -> { where(published: true) }
  scope :upcoming, -> { where("starts_at >= ?", Time.current).order(starts_at: :asc) }
  scope :past, -> { where("starts_at < ?", Time.current).order(starts_at: :desc) }

  DISPLAY_ZONES = [
    [ "America/New_York", "ET" ],
    [ "Europe/London", "London" ],
    [ "Europe/Berlin", "Berlin" ]
  ].freeze

  def self.default_pin_color = "#1d4ed8"      # blue-700
  def self.default_pin_icon  = "calendar-days"
  def self.map_category      = :event

  private

  def ends_at_after_starts_at
    return if ends_at.blank? || starts_at.blank?
    errors.add(:ends_at, "must be after the start time") if ends_at <= starts_at
  end
end
