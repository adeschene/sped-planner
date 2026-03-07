class Timeslot < ApplicationRecord
  has_many :activities, foreign_key: :block, primary_key: :position, dependent: :nullify

  validates :label, presence: true
  validates :position, presence: true, uniqueness: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  default_scope { order(:position) }
end
