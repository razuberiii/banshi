class LevelEvaluator
  def self.call(entry, now: Time.current)
    entry.with_lock do
      return entry unless %w[NORMAL HOT].include?(entry.level) && entry.merged_into_id.nil?
      cutoff = now - AppConfig.distribution.hot_window
      recent_natural = entry.natural_occurrences.where(occurred_at: cutoff..now).count
      recent_trial = entry.latest_trial_result
      hot_score = recent_trial && recent_trial.created_at >= cutoff && recent_trial.distribution_score >= AppConfig.distribution.hot_score_threshold
      hot = recent_natural >= AppConfig.distribution.hot_min_natural || hot_score
      target = hot ? 'HOT' : 'NORMAL'
      return entry if entry.level == target
      previous = entry.level
      entry.update!(level: target)
      TimelineEvent.create!(shit_entry: entry, event_type: target == 'HOT' ? 'hot' : 'cooled',
        label: target == 'HOT' ? '近期传播升温' : '近期热度回落', occurred_at: now,
        details: { from: previous, to: target, recent_natural_occurrences: recent_natural,
          natural_threshold: AppConfig.distribution.hot_min_natural, score_threshold: AppConfig.distribution.hot_score_threshold,
          window_seconds: AppConfig.distribution.hot_window }, dedupe_key: "level:#{entry.id}:#{target}:#{now.iso8601(6)}")
    end
    entry
  end
end
