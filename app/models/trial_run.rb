class TrialRun < ApplicationRecord
  belongs_to :shit_entry
  has_many :trial_deliveries
  has_many :deliveries
  has_one :trial_result
  scope :active, -> { where(status: %w[pending running]) }
end
