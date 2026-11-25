class Users::RegistrationsController < Devise::RegistrationsController
  protect_from_spam limit: 3, within: 1.hour
  before_action :require_form_render_token, only: :create
end
