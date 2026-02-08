class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum :role, { contributor: 0, admin: 1 }

  has_many :memories, dependent: :nullify

  validates :name, presence: true
end
