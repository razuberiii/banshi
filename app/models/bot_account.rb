class BotAccount < ApplicationRecord
  has_many :bot_connections
  has_many :group_bot_memberships
  validates :external_id, presence: true, uniqueness: true
end
