class SafetyEvaluator
  # Platform hard bans are not removable through group preferences or runtime
  # configuration. Configuration may add further restrictions.
  HARD_BLOCK_TAGS = %w[PRIVACY EXTREME].freeze
  Result = Struct.new(:reasons, keyword_init: true) do
    def allowed? = reasons.empty?
  end

  def self.resume!(entry:, user:, reason:)
    raise SecurityError, 'curator review required' unless user&.curator?
    raise ArgumentError, 'a review reason is required' if reason.to_s.strip.empty?
    entry.with_lock do
      raise ArgumentError, '请先处理所有未决举报' if entry.reports.where(status:'open').exists?
      result=call(entry:entry)
      restrictions=result.reasons-['distribution_paused']
      raise ArgumentError, "尚不能恢复传播：#{restrictions.join(', ')}" if restrictions.any?
      entry.update!(distribution_paused:false)
      audit=AuditLog.create!(shit_entry:entry,user:user,category:'safety',action:'resume_distribution',details:{reason:reason})
      TimelineEvent.create!(shit_entry:entry,event_type:'distribution_resumed',label:'人工复核后恢复传播',
        occurred_at:Time.current,details:{audit_id:audit.id},dedupe_key:"resume:#{audit.id}")
    end
    if %w[NORMAL HOT CLASSIC].include?(entry.level)
      DistributionJob.perform_later(entry.id)
    elsif entry.candidates.where(status:'accepted').exists?
      TrialDispatchJob.perform_later(entry.id)
    end
    entry
  end

  def self.call(entry:, group: nil)
    reasons = []
    reasons << 'merged_entry' if entry.merged_into_id
    reasons << 'red_safety_level' if entry.safety_level == 'RED'
    reasons << 'media_not_public' unless entry.visibility == 'public'
    reasons << 'distribution_paused' if entry.distribution_paused?
    hard_tags = HARD_BLOCK_TAGS | AppConfig.safety.hard_block_tags
    reasons << 'platform_hard_block_tag' if (entry.safety_tags & hard_tags).any?
    if group && (entry.safety_level == 'YELLOW' || entry.safety_tags.any?)
      reasons << 'group_does_not_accept_all_tags' if (entry.safety_tags - group.accepted_tags).any?
    end
    asset_ids = entry.content.assets.pluck(:id) | entry.content.forward_nodes.where.not(asset_id: nil).pluck(:asset_id)
    assets = Asset.where(id: asset_ids)
    reasons << 'asset_not_visible' if assets.where.not(visibility: 'visible').exists?
    reasons << 'file_blacklist' if assets.where(sha256: AppConfig.safety.file_blacklist).exists?
    source_identifiers = [entry.first_group.external_id, entry.first_group_id.to_s]
    reasons << 'source_blacklist' if (source_identifiers & AppConfig.safety.source_blacklist).any?
    Result.new(reasons: reasons.uniq.freeze)
  end

  def self.mark!(entry:, level:, tags:, visibility:, reason:, user: nil, source: 'manual')
    raise ArgumentError, 'a review reason is required' if reason.to_s.strip.empty?
    raise ArgumentError, 'unknown safety level' unless %w[GREEN YELLOW RED].include?(level)
    raise ArgumentError, 'unknown visibility' unless %w[public metadata_only hidden].include?(visibility)
    tags = Array(tags).map(&:to_s).uniq
    raise ArgumentError, 'unknown safety tag' unless (tags - AppConfig.safety.tags).empty?
    raise SecurityError, 'curator review required' if source == 'manual' && user && !user.curator?
    now = Time.current
    decision = entry.with_lock do
      hard = (tags & (HARD_BLOCK_TAGS | AppConfig.safety.hard_block_tags)).any?
      actual_level = hard ? 'RED' : level=='GREEN' && tags.any? ? 'YELLOW' : level
      actual_visibility = actual_level == 'RED' ? 'hidden' : visibility
      entry.update!(safety_level: actual_level, safety_tags: tags, visibility: actual_visibility)
      record = SafetyDecision.create!(shit_entry: entry, user: user, level: actual_level,
        tags: tags, visibility: actual_visibility, source: source, rule: hard ? 'platform_hard_block' : 'explicit_review',
        reason: reason, decided_at: now)
      AuditLog.create!(shit_entry: entry, user: user, category: 'safety', action: 'mark',
        details: { decision_id: record.id, level: actual_level, tags: tags, visibility: actual_visibility, source: source, reason: reason })
      TimelineEvent.create!(shit_entry: entry, event_type: 'safety_review', label: '安全审核', occurred_at: now,
        details: { decision_id: record.id, level: actual_level, visibility: actual_visibility }, dedupe_key: "safety:#{record.id}")
      record
    end
    if call(entry: entry).allowed? && entry.candidates.where(status: 'accepted').exists? && !entry.trial_runs.where(status: 'finished').exists?
      TrialDispatchJob.perform_later(entry.id) if AppConfig.trial.enabled
      DistributionJob.perform_later(entry.id) unless AppConfig.trial.required_before_distribution
    end
    decision
  end
end
