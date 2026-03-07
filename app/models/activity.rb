class Activity < ApplicationRecord
  has_many :notes, dependent: :destroy
  belongs_to :timeslot, foreign_key: :block, primary_key: :position, optional: true

  validates :title, :date, :block, presence: true

  default_scope { order(block: :asc, updated_at: :asc) }

  def start_time
  	self.date
  end
end
