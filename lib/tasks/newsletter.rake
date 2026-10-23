namespace :newsletter do
  desc "Email a confirmation link to every unconfirmed subscriber who hasn't been sent one"
  task send_confirmations: :environment do
    sent = 0
    NewsletterSubscriber.unconfirmed.where(confirmation_sent_at: nil).find_each do |subscriber|
      subscriber.send_confirmation(deliver: :deliver_now)
      sent += 1
      sleep 0.25 # stay under Resend's per-second rate limit
    end
    puts "Sent #{sent} confirmation emails."
  end
end
