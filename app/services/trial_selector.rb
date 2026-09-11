class TrialSelector
  def self.call(entry:, now: Time.current)
    return [] unless AppConfig.features.trial && AppConfig.trial.enabled && SafetyEvaluator.call(entry: entry).allowed?
    groups = Group.where(trial_preference: AppConfig.trial.required_before_distribution ? %w[OPT_IN FALLBACK] : ['OPT_IN'])
      .order(Arel.sql("CASE trial_preference WHEN 'OPT_IN' THEN 0 ELSE 1 END"))
      .order(Arel.sql('last_trial_at ASC NULLS FIRST'), :id)
    selected = []
    groups.each do |group|
      next unless GroupMatcher.call(entry: entry, group: group, kind: 'BOT_TRIAL', now: now).allowed?
      selected << group
      break if selected.length >= AppConfig.trial.group_max
    end
    selected
  end
end
