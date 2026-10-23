class ResendNewsletterRemoveJob < ApplicationJob
  retry_on Resend::Error::RateLimitExceededError, Resend::Error::InternalServerError,
           Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET,
           wait: :polynomially_longer, attempts: 10
  discard_on Resend::Error::NotFoundError

  def perform(email)
    Resend::Contacts::Segments.remove(email: email, segment_id: ENV.fetch("RESEND_NEWSLETTER_SEGMENT_ID"))
  end
end
