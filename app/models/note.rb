class Note < ApplicationRecord
  belongs_to :activity

  validates :body, presence: true
end
