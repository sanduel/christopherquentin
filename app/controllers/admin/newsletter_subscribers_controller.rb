require "csv"

class Admin::NewsletterSubscribersController < Admin::BaseController
  def index
    @subscribers = NewsletterSubscriber.order(created_at: :desc)

    respond_to do |format|
      format.html
      format.csv do
        send_data subscribers_csv(@subscribers),
                  filename: "subscribers-#{Date.current.iso8601}.csv",
                  type: "text/csv"
      end
    end
  end

  def destroy
    subscriber = NewsletterSubscriber.find(params[:id])
    subscriber.destroy
    redirect_to admin_newsletter_subscribers_path, notice: "Subscriber removed."
  end

  private

  def subscribers_csv(subscribers)
    CSV.generate do |csv|
      csv << [ "Email", "Subscribed at" ]
      subscribers.each do |subscriber|
        csv << [ subscriber.email, subscriber.created_at.iso8601 ]
      end
    end
  end
end
