namespace :newsletter do
  desc "Mark the given subscribers confirmed and add them to the Resend segment without emailing them (IDS=1,2,3)"
  task import_existing: :environment do
    ids = ENV.fetch("IDS").split(",").map(&:strip)
    imported = 0
    failed = 0

    NewsletterSubscriber.unconfirmed.where(id: ids).find_each do |subscriber|
      attempts = 0
      begin
        ResendNewsletterSyncJob.new.perform(subscriber.email)
        subscriber.update!(confirmed_at: Time.current)
        imported += 1
      rescue Resend::Error::RateLimitExceededError => e
        attempts += 1
        sleep(e.retry_after || 1)
        retry if attempts < 3
        failed += 1
        warn "Rate limited, skipped #{subscriber.email}"
      rescue Resend::Error => e
        failed += 1
        warn "Failed to import #{subscriber.email}: #{e.message}"
      end
      sleep 0.25 # stay under Resend's per-second rate limit
    end

    puts "Imported #{imported}, #{failed} failed."
  end

  desc "Re-queue every confirmed subscriber for the Resend newsletter segment"
  task resync: :environment do
    emails = NewsletterSubscriber.confirmed.pluck(:email)
    emails.each { |email| ResendNewsletterSyncJob.perform_later(email) }
    puts "Queued #{emails.size} subscribers for sync."
  end
end
