class Milestone < ApplicationRecord
  validates :date,     presence: true
  validates :headline, presence: true

  scope :chronological, -> { order(:date) }

  def year = date.year
  def age  = year - Memory::CHRIS_BIRTH_YEAR
end
