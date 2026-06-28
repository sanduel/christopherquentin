class Tribute < ApplicationRecord
  enum :status, { pending: 0, published: 1, rejected: 2 }
  enum :category, { family: 0, colleagues: 1, musicians: 2, students: 3, friends: 4 }, prefix: :category

  belongs_to :user, optional: true
  has_one_attached :photo

  validates :name, presence: true
  validate :content_or_video_present
  validate :video_url_must_be_youtube
  before_validation :normalize_video_url

  def video?
    video_url.present?
  end

  # Extracts the 11-character video id from common YouTube URL shapes
  # (watch, youtu.be, embed, shorts, live). Returns nil if it isn't a
  # YouTube link. A missing scheme is tolerated so pasted URLs like
  # "youtube.com/watch?v=..." still parse.
  def youtube_id
    return if video_url.blank?

    raw = video_url.strip
    raw = "https://#{raw}" unless raw.match?(%r{\Ahttps?://}i)

    uri = begin
      URI.parse(raw)
    rescue URI::InvalidURIError
      nil
    end
    return if uri&.host.nil?

    host = uri.host.downcase.delete_prefix("www.").delete_prefix("m.")
    path = uri.path.to_s

    id =
      if host == "youtu.be"
        path.delete_prefix("/")
      elsif host == "youtube.com"
        if path == "/watch"
          Rack::Utils.parse_query(uri.query)["v"]
        elsif path.start_with?("/embed/", "/shorts/", "/live/")
          path.split("/")[2]
        end
      end

    id if id&.match?(/\A[A-Za-z0-9_-]{11}\z/)
  end

  def youtube_embed_url
    "https://www.youtube.com/embed/#{youtube_id}?rel=0" if youtube_id
  end

  def youtube_thumbnail_url
    "https://img.youtube.com/vi/#{youtube_id}/hqdefault.jpg" if youtube_id
  end

  private

  # Canonicalize a valid YouTube link to a clean watch URL so stored data is
  # always an absolute, predictable URL (fixes scheme-less pastes and links).
  def normalize_video_url
    return if video_url.blank?

    id = youtube_id
    self.video_url = "https://www.youtube.com/watch?v=#{id}" if id
  end

  def content_or_video_present
    return if content.present? || video_url.present?

    errors.add(:base, "Add a written tribute or a YouTube video.")
  end

  def video_url_must_be_youtube
    return if video_url.blank?

    errors.add(:video_url, "must be a valid YouTube link") if youtube_id.blank?
  end
end
