class NewsletterMailer < ApplicationMailer
  def confirmation(subscriber)
    @confirmation_url = newsletter_confirmation_url(subscriber.generate_token_for(:confirmation))
    mail to: subscriber.email, subject: "Please confirm your subscription"
  end
end
