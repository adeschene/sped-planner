class Activity < ApplicationRecord
  has_many :notes, dependent: :destroy

  enum block: [:nine_thirty, :ten_thirty, :eleven_thirty, :lunch, :one, :two, :three]

  validates :title, :date, :block, presence: true

  def start_time
  	self.date
  end
end
