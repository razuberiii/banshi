class Message < ApplicationRecord
  belongs_to :group
  belongs_to :transporter, optional: true
  belongs_to :bot_account, optional: true
  belongs_to :internal_event, optional: true
  belongs_to :content, optional: true
  has_one :candidate
  has_one :shit_occurrence
  has_many :interactions
  validates :external_id, uniqueness: { scope: :group_id }
end
