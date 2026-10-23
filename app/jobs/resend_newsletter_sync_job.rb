class ResendNewsletterSyncJob < ApplicationJob
  retry_on Resend::Error::RateLimitExceededError, wait: :polynomially_longer, attempts: 10

  def perform(subscriber)
    segment_id = ENV.fetch("RESEND_NEWSLETTER_SEGMENT_ID")

    if contact_exists?(subscriber.email)
      Resend::Contacts.update(email: subscriber.email, unsubscribed: false)
      Resend::Contacts::Segments.add(email: subscriber.email, segment_id: segment_id)
    else
      Resend::Contacts.create(email: subscriber.email, unsubscribed: false, segments: [ { id: segment_id } ])
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
