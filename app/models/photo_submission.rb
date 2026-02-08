class PhotoSubmission < ApplicationRecord
  enum :status, { pending: 0, published: 1, rejected: 2 }

  has_many_attached :photos

  validates :name, :email, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
end
