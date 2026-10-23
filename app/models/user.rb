class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum :role, { contributor: 0, admin: 1 }

  has_many :memories, dependent: :nullify

  validates :name, presence: true

  # Queue Devise emails so a slow or failing mail API can't break the request.
  def send_devise_notification(notification, *args)
    devise_mailer.send(notification, self, *args).deliver_later
  end
end
