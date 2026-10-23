class NewsletterSubscriber < ApplicationRecord
  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  # The address is used as a path segment in Resend API calls.
  validates :email, format: { without: %r{[/?#%\\]}, message: "contains unsupported characters" }

  scope :confirmed, -> { where.not(confirmed_at: nil) }
  scope :unconfirmed, -> { where(confirmed_at: nil) }

  generates_token_for :confirmation, expires_in: 14.days do
    confirmed_at
  end

  def confirmed?
    confirmed_at.present?
  end

  def confirmation_recently_sent?
    confirmation_sent_at.present? && confirmation_sent_at > 1.hour.ago
  end

  def send_confirmation(deliver: :deliver_later)
    NewsletterMailer.confirmation(self).public_send(deliver)
    update!(confirmation_sent_at: Time.current)
  end

  def confirm!
    update!(confirmed_at: Time.current)
    ResendNewsletterSyncJob.perform_later(email)
  end
end
