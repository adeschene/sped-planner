class Activity < ApplicationRecord
  has_many :notes, dependent: :destroy

  validates :title, :date, :block, presence: true

  def start_time
  	self.date
  end
end
