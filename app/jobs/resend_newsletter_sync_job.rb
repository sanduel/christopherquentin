class ResendNewsletterSyncJob < ApplicationJob
  retry_on Resend::Error::RateLimitExceededError, Resend::Error::InternalServerError,
           Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET,
           wait: :polynomially_longer, attempts: 10

  def perform(email)
    segment_id = ENV.fetch("RESEND_NEWSLETTER_SEGMENT_ID")

    if contact_exists?(email)
      Resend::Contacts.update(email: email, unsubscribed: false)
      Resend::Contacts::Segments.add(email: email, segment_id: segment_id)
    else
      Resend::Contacts.create(email: email, unsubscribed: false, segments: [ { id: segment_id } ])
    end
  end

  private

  def contact_exists?(email)
    Resend::Contacts.get(email: email)
    true
  rescue Resend::Error::NotFoundError
    false
  end
end
