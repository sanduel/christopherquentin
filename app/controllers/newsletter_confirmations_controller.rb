# Confirmation is a GET that shows a button and a POST that confirms, because email
# link scanners fetch every link in incoming mail and would otherwise auto-confirm
# addresses that bots signed up.
class NewsletterConfirmationsController < ApplicationController
  before_action :set_subscriber

  def show
  end

  def create
    @subscriber.confirm!
    render :confirmed
  end

  private

  def set_subscriber
    @subscriber = NewsletterSubscriber.find_by_token_for(:confirmation, params[:token])
    render :expired, status: :not_found unless @subscriber
  end
end
