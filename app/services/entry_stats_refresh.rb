class EntryStatsRefresh
  def self.call(entry)
    entry.with_lock do
      natural = entry.natural_occurrences.order(:occurred_at, :id).to_a
      first = natural.first
      revivals = natural.each_cons(2).filter_map do |previous, current|
        current if current.occurred_at - previous.occurred_at >= AppConfig.classic.revival_gap
      end
      attributes = { natural_count: natural.length, bot_count: entry.shit_occurrences.bot.count,
        natural_group_count: natural.map(&:group_id).uniq.length, revival_count: revivals.length,
        interaction_count: entry.interaction_scope.joins(:message)
          .where('messages.transporter_id IS NULL OR messages.transporter_id <> interactions.transporter_id')
          .distinct.count(:transporter_id) }
      if first
        attributes.merge!(first_seen_at: first.occurred_at, last_natural_at: natural.last.occurred_at,
          first_group_id: first.group_id, first_transporter_id: first.transporter_id)
      end
      entry.update!(attributes)
      entry.shit_occurrences.where(first_appearance: true).where.not(id: first&.id).update_all(first_appearance: false)
      first.update!(first_appearance: true) if first && !first.first_appearance?

      valid_keys = revivals.map { |occurrence| "revival:#{entry.id}:#{occurrence.id}" }
      entry.timeline_events.where(event_type: 'revival').where.not(dedupe_key: valid_keys).delete_all
      revivals.each do |occurrence|
        TimelineEvent.create_or_find_by!(dedupe_key: "revival:#{entry.id}:#{occurrence.id}") do |event|
          event.assign_attributes(shit_entry: entry, group_id: occurrence.group_id, transporter_id: occurrence.transporter_id,
            event_type: 'revival', label: '自然复兴', occurred_at: occurrence.occurred_at,
            details: { occurrence_id: occurrence.id, minimum_gap_seconds: AppConfig.classic.revival_gap })
        end
      end
    end
    entry
  end
end
