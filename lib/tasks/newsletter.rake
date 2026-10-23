namespace :newsletter do
  desc "Email a confirmation link to every unconfirmed subscriber who hasn't been sent one"
  task send_confirmations: :environment do
    sent = 0
    failed = 0

    NewsletterSubscriber.unconfirmed.where(confirmation_sent_at: nil).find_each do |subscriber|
      attempts = 0
      begin
        subscriber.send_confirmation(deliver: :deliver_now)
        sent += 1
      rescue Resend::Error::RateLimitExceededError => e
        attempts += 1
        sleep(e.retry_after || 1)
        retry if attempts < 3
        failed += 1
        warn "Rate limited, skipped #{subscriber.email}"
      rescue Resend::Error => e
        failed += 1
        warn "Failed to send to #{subscriber.email}: #{e.message}"
      end
      sleep 0.25 # stay under Resend's per-second rate limit
    end

    puts "Sent #{sent} confirmation emails, #{failed} failed."
  end

  desc "Re-queue every confirmed subscriber for the Resend newsletter segment"
  task resync: :environment do
    emails = NewsletterSubscriber.confirmed.pluck(:email)
    emails.each { |email| ResendNewsletterSyncJob.perform_later(email) }
    puts "Queued #{emails.size} subscribers for sync."
  end
end
