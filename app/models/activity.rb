class Activity < ApplicationRecord
  has_many :notes, dependent: :destroy

  enum block: [:'9:30AM', :'10:30AM', :'11:30AM', :Lunch, :'1:00PM', :'2:00PM', :'3:00PM']

  validates :title, :date, :block, presence: true

  def start_time
  	self.date
  end
end
