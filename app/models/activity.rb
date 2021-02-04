class Activity < ApplicationRecord
  has_many :notes, dependent: :destroy

  validates :title, :date, :block, presence: true

  default_scope { order(block: :asc, updated_at: :asc) }

  def start_time
  	self.date
  end
end
