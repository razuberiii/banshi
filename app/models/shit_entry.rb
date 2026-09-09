class ShitEntry < ApplicationRecord
  LEVELS = %w[ARCHIVED TRIAL NORMAL HOT CLASSIC].freeze
  belongs_to :content
  belongs_to :first_group, class_name: 'Group'
  belongs_to :first_transporter, class_name: 'Transporter', optional: true
  belongs_to :merged_into, class_name: 'ShitEntry', optional: true
  has_many :candidates
  has_many :shit_occurrences
  has_many :timeline_events, -> { order(:occurred_at, :id) }
  has_many :trial_runs
  has_many :deliveries
  has_many :safety_decisions
  has_many :reports
  has_many :web_ratings
  has_many :favorites
  has_many :duplicate_matches
  before_validation :assign_sid, on: :create
  validates :sid, presence: true, uniqueness: true
  validates :title,length:{maximum:120},allow_nil:true
  validates :summary,length:{maximum:2000},allow_nil:true
  validates :level, inclusion: { in: LEVELS }
  validates :safety_level, inclusion: { in: %w[GREEN YELLOW RED] }
  validates :visibility, inclusion: { in: %w[public metadata_only hidden] }
  scope :unmerged, -> { where(merged_into_id: nil) }
  scope :publicly_visible, -> { unmerged.joins(:first_group).where(visibility: 'public', safety_level: %w[GREEN YELLOW], groups: { visibility: 'public' }) }
  scope :recent, -> { order(first_seen_at: :desc) }
  def to_param = sid
  def display_title = title.presence || sid
  def lifespan_days = [(last_natural_at.to_date - first_seen_at.to_date).to_i, 0].max
  def public? = visibility == 'public' && safety_level != 'RED' && merged_into_id.nil? && first_group.visibility == 'public'
  def latest_trial_result = TrialResult.joins(:trial_run).where(trial_runs: { shit_entry_id: id }).order(created_at: :desc).first
  def natural_occurrences = shit_occurrences.where(source: 'NATURAL')
  def interaction_scope
    Interaction.where(message_id: shit_occurrences.select(:message_id), active: true)
  end
  private
  def assign_sid
    self.id ||= self.class.connection.select_value("SELECT nextval(pg_get_serial_sequence('shit_entries', 'id'))").to_i
    self.sid ||= format('S-%06d', id)
  end
end
