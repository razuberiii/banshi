class LeaderboardRefresh
  def self.call
    now = Time.current
    cutoff = now - AppConfig.leaderboard.period
    limit = AppConfig.leaderboard.limit
    entries = ShitEntry.publicly_visible
    period = ArchivePeriodMetrics.call(now:now)
    boards = {
      'fastest' => period[:reach].sort_by { |id,count| [-count,id] }.first(limit).map { |id,count| {id:id,value:count} },
      'natural' => entries.order(natural_count: :desc, id: :asc).limit(limit).map { |entry| row(entry, entry.natural_count) },
      'cross_group' => entries.order(natural_group_count: :desc, id: :asc).limit(limit).map { |entry| row(entry, entry.natural_group_count) },
      'longevity' => entries.order(Arel.sql('(last_natural_at - first_seen_at) DESC'), :id).limit(limit).map { |entry| row(entry, entry.lifespan_days) },
      'revivals' => entries.order(revival_count: :desc, id: :asc).limit(limit).map { |entry| row(entry, entry.revival_count) },
      'new_classics' => entries.where(level: 'CLASSIC', classic_at: cutoff..now).order(classic_at: :desc, id: :asc).limit(limit).map { |entry| row(entry, entry.natural_count) },
      'transporters' => Transporter.public_profiles.order(reputation_score: :desc, accepted_count: :desc, id: :asc).limit(limit).map { |person| row(person, person.reputation_score) },
      'groups' => Group.public_archives.to_a.sort_by { |group| [-group.stats.fetch('natural_occurrences', 0), group.id] }.first(limit).map { |group| row(group, group.stats.fetch('natural_occurrences', 0)) },
      'trial_groups' => Group.public_archives.to_a.sort_by { |group| [-group.stats.fetch('responsive_trials', 0), group.id] }.first(limit).map { |group| row(group, group.stats.fetch('responsive_trials', 0)) }
    }
    # Only real completed trials participate in the explicit-negative board.
    bad_scores = TrialResult.joins(:trial_run).where(trial_runs: { shit_entry_id: entries.select(:id) }).group('trial_runs.shit_entry_id').maximum(:negative_rate)
    boards['bad'] = bad_scores.select { |_,value| value.positive? }.sort_by { |id, value| [-value, id] }.first(limit).map { |id, value| { id: id, value: value } }
    LeaderboardSnapshot.transaction do
      boards.map do |name, rows|
        snapshot = LeaderboardSnapshot.find_or_initialize_by(board: name)
        snapshot.update!(generated_at: now, rows: rows)
        snapshot
      end
    end
  end

  def self.row(record, value) = { id: record.id, value: value }
  private_class_method :row
end
