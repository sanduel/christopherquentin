class NewsletterSubscribersController < ApplicationController
  protect_from_spam limit: 5, within: 10.minutes

  # Responds identically whether or not the address is already subscribed, so the
  # form can't be used to discover who is on the list. Confirmed subscribers are
  # emailed too, so their owner can re-subscribe after unsubscribing in Resend.
  def create
    @subscriber = NewsletterSubscriber.find_or_initialize_by(email: subscriber_params[:email])

    if @subscriber.save
      @subscriber.send_confirmation unless @subscriber.confirmation_recently_sent?
      redirect_back fallback_location: root_path, notice: CHECK_EMAIL
    else
      redirect_back fallback_location: root_path, alert: "Could not subscribe. Please check your email."
    end
  rescue ActiveRecord::RecordNotUnique
    redirect_back fallback_location: root_path, notice: CHECK_EMAIL
  end

  private

  CHECK_EMAIL = "Thanks! Check your email and click the link to confirm your subscription.".freeze

  def subscriber_params
    params.permit(:name, :email)
  end
end
