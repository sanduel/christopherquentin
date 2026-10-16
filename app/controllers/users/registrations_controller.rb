class Users::RegistrationsController < Devise::RegistrationsController
  protect_from_spam limit: 3, within: 1.hour
end
