class ClassicEvaluator
  def self.call(entry, now: Time.current)
    return entry unless AppConfig.features.auto_classic && entry.merged_into_id.nil?
    EntryStatsRefresh.call(entry)
    entry.with_lock do
      return entry if entry.level == 'CLASSIC'
      config = AppConfig.classic
      natural_span = entry.natural_count.positive? ? entry.last_natural_at - entry.first_seen_at : 0
      qualified = entry.natural_count >= config.min_natural_occurrences &&
        entry.natural_group_count >= config.min_groups && natural_span >= config.min_lifespan &&
        entry.revival_count >= config.min_revivals
      return entry unless qualified
      entry.update!(level: 'CLASSIC', classic_at: now)
      TimelineEvent.create_or_find_by!(dedupe_key: "entry:#{entry.id}:classic") do |event|
        event.assign_attributes(shit_entry: entry, event_type: 'classic', label: '自然传播积累为经典', occurred_at: now,
          details: { natural_count: entry.natural_count, natural_groups: entry.natural_group_count,
            natural_lifespan_seconds: natural_span, revivals: entry.revival_count,
            thresholds: { occurrences: config.min_natural_occurrences, groups: config.min_groups,
              lifespan_seconds: config.min_lifespan, revivals: config.min_revivals } })
      end
      ReputationRefreshJob.perform_later(entry.first_transporter_id) if entry.first_transporter_id
    end
    entry
  end
end
