class Group < ApplicationRecord
  has_many :group_bot_memberships, dependent: :destroy
  has_many :bot_accounts, through: :group_bot_memberships
  has_many :group_members, dependent: :destroy
  has_many :transporters, through: :group_members
  has_many :group_managements, dependent: :destroy
  has_many :candidates
  has_many :messages
  has_many :shit_occurrences
  has_many :discovered_entries, class_name: 'ShitEntry', foreign_key: :first_group_id
  has_many :deliveries
  has_many :trial_deliveries
  has_many :timeline_events
  scope :listed, -> { where.not(visibility: 'hidden') }
  scope :public_archives, -> { where(visibility: 'public') }
  validates :external_id, :slug, :public_name, :anonymous_name, :joined_at, presence: true
  validates :external_id, :slug, uniqueness: true
  validates :visibility, inclusion: { in: %w[public statistics hidden] }
  validates :trial_preference, inclusion: { in: %w[OPT_IN FALLBACK OPT_OUT] }
  validates :daily_limit, :cooldown_minutes, numericality: { greater_than_or_equal_to: 0, only_integer: true }, allow_nil: true
  validate { errors.add(:accepted_tags, '包含未定义标签') unless (accepted_tags - AppConfig.safety.tags).empty? }
  def display_name = anonymous? ? anonymous_name : public_name
  def to_param = slug
  def can_collect? = collect_enabled.nil? ? BotModeParser.call(mode).fetch(:collect) : collect_enabled
  def can_distribute? = distribute_enabled.nil? ? BotModeParser.call(mode).fetch(:distribute) : distribute_enabled
  def effective_daily_limit = daily_limit || AppConfig.distribution.daily_limit
  def cooldown = cooldown_minutes.nil? ? AppConfig.distribution.cooldown : cooldown_minutes.minutes
  def available_connection
    BotConnection.joins(bot_account: :group_bot_memberships).where(group_bot_memberships: { group_id: id, active: true }, bot_accounts: { active: true }, status: 'online').order(:id).first
  end
  def public_archive? = visibility == 'public' && AppConfig.features.public_groups
end
