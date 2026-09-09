class Candidate < ApplicationRecord
  STATUSES = %w[pending accepted expired rejected duplicate unsafe].freeze
  belongs_to :message
  belongs_to :group
  belongs_to :transporter, optional: true
  belongs_to :content
  belongs_to :shit_entry, optional: true
  validates :message_id, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  scope :pending, -> { where(status: 'pending') }
  scope :due, -> { pending.where('expires_at <= ?', Time.current) }
  def interactions = Interaction.where(group_id: group_id, target_external_id: message.external_id, active: true).where.not(transporter_id: transporter_id)
  def pending? = status == 'pending'
end
