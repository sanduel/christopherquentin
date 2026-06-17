class Reply < ApplicationRecord
  enum :status, { pending: 0, published: 1, rejected: 2 }

  belongs_to :memory
  belongs_to :user, optional: true

  validates :name, presence: true
  validates :body, presence: true
  validates :email, presence: true, if: -> { user_id.blank? }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "is invalid" }, allow_blank: true

  scope :published, -> { where(status: :published) }
end
