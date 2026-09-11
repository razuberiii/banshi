class CandidateEvaluator
  def self.call(candidate:, now: Time.current)
    changed = false
    candidate.with_lock do
      return candidate unless candidate.pending?
      # A fingerprint may be observed concurrently in several groups. Serialize the
      # final admission/duplicate check, not network I/O, using PostgreSQL's lock.
      Candidate.connection.execute('SELECT pg_advisory_xact_lock(713401)')
      match = DuplicateDetector.call(content: candidate.content)
      rules = evidence(candidate, now)
      candidate.assign_attributes(score: rules.fetch('score'), rule_results: rules,
        evaluated_at: now, duplicate_status: match.status, duplicate_confidence: match.confidence)

      if match.status == 'confirmed' && match.entry
        candidate.assign_attributes(status: 'duplicate', shit_entry: match.entry,
          decision_reason: '已确认重复：保留原 S-ID，记录新的自然出现')
        OccurrenceRecorder.call(entry: match.entry, message: candidate.message,
          duplicate_matched: true, confidence: match.confidence)
        changed = true
      elsif now < candidate.expires_at
        candidate.decision_reason = '观察窗口尚未结束'
      elsif candidate.message.sent_at < now - AppConfig.candidate.max_late_age
        candidate.assign_attributes(status: 'expired', decision_reason: '消息超过允许补录时间；不追认候选')
        changed = true
      elsif rules.fetch('eligible')
        entry = ShitEntry.create!(content: candidate.content, first_group: candidate.group,
          first_transporter: candidate.transporter, first_seen_at: candidate.message.sent_at,
          last_natural_at: candidate.message.sent_at, safety_level: AppConfig.safety.default_level,
          visibility: AppConfig.safety.default_visibility, level: AppConfig.trial.required_before_distribution ? 'ARCHIVED' : 'NORMAL')
        candidate.assign_attributes(status: 'accepted', shit_entry: entry, decision_reason: '观察期结束：独立参与者与规则得分达标')
        OccurrenceRecorder.call(entry: entry, message: candidate.message)
        TimelineEvent.create_or_find_by!(dedupe_key: "candidate:#{candidate.id}:accepted") do |event|
          event.assign_attributes(shit_entry: entry, group: candidate.group, transporter: candidate.transporter,
            event_type: 'collected', label: '候选正式入库', occurred_at: now, details: rules)
        end
        if SafetyEvaluator.call(entry: entry).allowed?
          TrialDispatchJob.perform_later(entry.id) if AppConfig.trial.enabled
          DistributionJob.perform_later(entry.id) unless AppConfig.trial.required_before_distribution
        end
        DomainLog.emit('candidate.accepted', candidate_id: candidate.id, sid: entry.sid)
        changed = true
      else
        candidate.assign_attributes(status: 'expired', decision_reason: '观察期结束：独立参与者或规则得分不足')
        changed = true
      end
      candidate.save!
    end
    ReputationRefreshJob.perform_later(candidate.transporter_id) if changed && candidate.transporter_id
    GroupStatsRefreshJob.perform_later(candidate.group_id) if changed
    candidate
  end

  def self.evidence(candidate, now)
    config = AppConfig.candidate
    cutoff = [now, candidate.expires_at].min
    interactions = candidate.interactions.where(occurred_at: candidate.message.sent_at..cutoff).to_a
    # Each person contributes only their strongest observed signal. Repeated
    # replies and multiple emoji by the same person cannot amplify the score.
    weights = { 'reply' => config.reply_weight, 'quote' => config.quote_weight, 'reaction' => config.reaction_weight }
    signals = {}
    interactions.each do |interaction|
      next unless weights.key?(interaction.kind)
      signals[interaction.transporter_id] = [signals.fetch(interaction.transporter_id, 0), weights.fetch(interaction.kind)].max
    end
    repeats = Message.joins(:content).where(source: 'NATURAL', bot_account_id: nil,
      contents: { fingerprint: candidate.content.fingerprint }, sent_at: candidate.message.sent_at..cutoff)
      .where.not(id: candidate.message_id).where.not(transporter_id: [nil, candidate.transporter_id].compact)
      .distinct.pluck(:transporter_id).compact
    repeats.each { |id| signals[id] = [signals.fetch(id, 0), config.repeat_weight].max }
    base = candidate.content.forward? ? config.forward_base : config.image_base
    evidence_score = signals.values.sum.to_f
    reputation = candidate.reputation_snapshot
    reputation_enabled = AppConfig.features.reputation && AppConfig.reputation.enabled
    settled_samples = candidate.transporter&.candidates&.where(status: %w[accepted duplicate expired rejected unsafe])&.count || 0
    enough_samples = settled_samples >= AppConfig.reputation.min_samples
    adjustment = reputation_enabled && enough_samples ? ((reputation - 0.5) * 2 * AppConfig.reputation.max_adjustment) : 0.0
    activity_score = [candidate.group.messages.where(source: 'NATURAL', sent_at: candidate.message.sent_at..cutoff).distinct.count(:transporter_id), 1].max
    activity_adjustment = config.activity_weight * Math.log(1 + activity_score)
    total = (base + evidence_score + adjustment + activity_adjustment).round(6)
    { 'unique_users' => signals.length, 'reply_users' => interactions.select { |i| i.kind == 'reply' }.map(&:transporter_id).uniq.length,
      'quote_users' => interactions.select { |i| i.kind == 'quote' }.map(&:transporter_id).uniq.length,
      'reaction_users' => interactions.select { |i| i.kind == 'reaction' }.map(&:transporter_id).uniq.length,
      'repeat_users' => repeats.length, 'base_score' => base, 'evidence_score' => evidence_score,
      'reputation_snapshot' => reputation, 'reputation_adjustment' => adjustment,
      'activity_adjustment' => activity_adjustment, 'score' => total,
      'minimum_score' => config.min_score, 'minimum_unique_users' => config.min_unique_users,
      'eligible' => evidence_score.positive? && signals.length >= config.min_unique_users && total >= config.min_score,
      'window_started_at' => candidate.message.sent_at.iso8601, 'window_ends_at' => candidate.expires_at.iso8601,
      'counting_rule' => '每位非作者仅取最强信号；信誉与活跃度不能单独入库；不分析文本语义' }
  end
  private_class_method :evidence
end
