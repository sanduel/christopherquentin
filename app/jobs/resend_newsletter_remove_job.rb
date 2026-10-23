class ResendNewsletterRemoveJob < ApplicationJob
  retry_on Resend::Error::RateLimitExceededError, wait: :polynomially_longer, attempts: 10

  def perform(email)
    Resend::Contacts::Segments.remove(email: email, segment_id: ENV.fetch("RESEND_NEWSLETTER_SEGMENT_ID"))
  end
end
