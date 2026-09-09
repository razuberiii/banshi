class WebRating < ApplicationRecord
  REACTIONS = %w[💩 😂 🏛️ 🥱].freeze
  belongs_to :user
  belongs_to :shit_entry
  validates :reaction, inclusion: { in: REACTIONS }
  validates :reaction, uniqueness: { scope: [:user_id, :shit_entry_id] }
end
