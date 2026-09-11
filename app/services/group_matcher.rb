class GroupMatcher
  RESERVED_STATUSES = %w[pending sending sent uncertain].freeze
  EFFECTIVE_TIME_SQL = "COALESCE(sent_at, (decision->>'reserved_at')::timestamptz, created_at)".freeze
  Result = Struct.new(:reasons, :connection, keyword_init: true) do
    def allowed? = reasons.empty?
  end

  # Unknown groups start at a neutral prior; silence is not a dislike.
  def self.score(group)
    stats = group.stats.fetch('distribution_response', {})
    positive = stats.fetch('positive', 0).to_f
    negative = stats.fetch('negative', 0).to_f
    replies = stats.fetch('replies', 0).to_f
    ((positive + replies + 1) / (positive + replies + negative + 2)).round(4)
  end

  def self.call(entry:, group:, kind:, now: Time.current, excluding_delivery: nil)
    reasons = SafetyEvaluator.call(entry: entry, group: group).reasons.dup
    reasons << 'unsupported_delivery_kind' unless %w[BOT_TRIAL BOT_DISTRIBUTION BOT_CLASSIC].include?(kind)
    reasons << 'entry_not_distributable' if kind != 'BOT_TRIAL' && !%w[NORMAL HOT CLASSIC].include?(entry.level)
    reasons << 'trial_already_finished' if kind == 'BOT_TRIAL' && excluding_delivery&.trial_run&.status == 'finished'
    reasons << 'group_distribution_disabled' unless group.can_distribute?
    connection = group.available_connection
    reasons << 'no_online_bot_membership' unless connection
    reasons << 'group_rejects_hot' if entry.level == 'HOT' && !group.accept_hot?
    reasons << 'group_rejects_classic' if (entry.level == 'CLASSIC' || kind == 'BOT_CLASSIC') && !group.accept_classic?
    reasons << 'trial_opt_out' if kind == 'BOT_TRIAL' && group.trial_preference == 'OPT_OUT'
    reasons << 'trial_disabled' if kind == 'BOT_TRIAL' && (!AppConfig.trial.enabled || !AppConfig.features.trial)
    reasons << 'distribution_disabled' unless AppConfig.distribution.enabled

    natural = entry.natural_occurrences.where(group_id: group.id)
    seen_naturally = group.id == entry.first_group_id || natural.exists?
    archaeology = kind == 'BOT_CLASSIC' && group.accept_archaeology?
    if seen_naturally
      last_natural = natural.maximum(:occurred_at) || entry.first_seen_at
      reasons << 'already_seen_naturally' unless archaeology && last_natural <= now - AppConfig.distribution.repeat_after
    end
    existing = entry.deliveries.where(group_id: group.id, status: RESERVED_STATUSES)
    existing = existing.where.not(id: excluding_delivery.id) if excluding_delivery
    if existing.exists?
      last_sent = existing.where(status: 'sent').maximum(:sent_at)
      can_repeat = archaeology && !existing.where.not(status: 'sent').exists? && last_sent && last_sent <= now - AppConfig.distribution.repeat_after
      reasons << 'already_delivered_or_reserved' unless can_repeat
    end

    reserved = Delivery.where(status: RESERVED_STATUSES)
    reserved = reserved.where.not(id: excluding_delivery.id) if excluding_delivery
    group_reserved = reserved.where(group_id: group.id)
    day_count = group_reserved.where("#{EFFECTIVE_TIME_SQL} >= ? AND #{EFFECTIVE_TIME_SQL} < ?", now.beginning_of_day, now.end_of_day).count
    reasons << 'daily_quota' if day_count >= group.effective_daily_limit
    last_reserved = group_reserved.maximum(Arel.sql(EFFECTIVE_TIME_SQL))
    last_time = [group.last_delivery_at, last_reserved].compact.max
    reasons << 'group_cooldown' if last_time && last_time + group.cooldown > now
    minute_count = reserved.where("#{EFFECTIVE_TIME_SQL} > ?", now - 60).count
    reasons << 'global_minute_quota' if minute_count >= AppConfig.distribution.global_per_minute
    Result.new(reasons: reasons.uniq.freeze, connection: connection)
  end
end
