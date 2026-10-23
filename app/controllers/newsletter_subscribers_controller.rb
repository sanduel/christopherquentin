class NewsletterSubscribersController < ApplicationController
  protect_from_spam limit: 5, within: 10.minutes

  def create
    @subscriber = NewsletterSubscriber.new(subscriber_params)

    if @subscriber.save
      redirect_back fallback_location: root_path, notice: "Thank you for subscribing!"
    else
      redirect_back fallback_location: root_path, alert: "Could not subscribe. Please check your email."
    end
  end

  private

  def subscriber_params
    params.permit(:name, :email)
  end
end
