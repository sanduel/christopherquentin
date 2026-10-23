class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :configure_permitted_parameters, if: :devise_controller?

  def self.protect_from_spam(limit:, within:)
    rate_limit to: limit, within: within, only: :create, with: -> { reject_rate_limited }
    invisible_captcha only: :create, on_spam: :reject_spam, on_timestamp_spam: :reject_spam
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :name ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :name ])
  end

  private

  def reject_spam
    redirect_back fallback_location: root_path, status: :see_other,
      alert: "Sorry, we couldn't accept that submission. Please try again."
  end

  def reject_rate_limited
    redirect_back fallback_location: root_path, status: :see_other,
      alert: "You're submitting too quickly. Please wait a few minutes and try again."
  end
end
