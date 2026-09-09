class ShitOccurrence < ApplicationRecord
  SOURCES = %w[NATURAL BOT_TRIAL BOT_DISTRIBUTION BOT_CLASSIC].freeze
  belongs_to :shit_entry
  belongs_to :group
  belongs_to :transporter, optional: true
  belongs_to :message
  belongs_to :delivery, optional: true
  belongs_to :trial_run, optional: true
  scope :natural, -> { where(source: 'NATURAL') }
  scope :bot, -> { where.not(source: 'NATURAL') }
  validates :source, inclusion: { in: SOURCES }
  validates :message_id, uniqueness: true
end
