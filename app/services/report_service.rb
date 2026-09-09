class ReportService
  def self.create!(entry:, user:, reason:, details:)
    entry.with_lock do
      existing = entry.reports.find_by(user: user, status: 'open')
      escalation = existing && AppConfig.safety.urgent_report_reasons.include?(reason) && !AppConfig.safety.urgent_report_reasons.include?(existing.reason)
      return existing if existing && !escalation
      report = if existing
        existing.update!(reason: reason, details: details)
        existing
      else
        entry.reports.create!(user: user, reason: reason, details: details, status: 'open')
      end
      AuditLog.create!(shit_entry: entry, user: user, category: 'report', action: escalation ? 'escalated' : 'created',
        details: { report_id: report.id, reason: report.reason })
      if AppConfig.safety.urgent_report_reasons.include?(reason)
        entry.update!(distribution_paused: true)
        asset_ids = entry.content.assets.pluck(:id) | entry.content.forward_nodes.where.not(asset_id: nil).pluck(:asset_id)
        Asset.where(id: asset_ids, visibility: 'visible').update_all(visibility: 'hidden', updated_at: Time.current)
        tags = entry.safety_tags | (reason == 'privacy' ? ['PRIVACY'] : ['OTHER_SENSITIVE'])
        SafetyEvaluator.mark!(entry: entry, level: 'RED', tags: tags, visibility: 'hidden',
          reason: "紧急举报待复核：#{Report::REASONS.fetch(reason)}", user: user, source: 'report')
      elsif entry.reports.where(status: 'open').distinct.count(:user_id) >= AppConfig.safety.report_pause_threshold
        entry.update!(distribution_paused: true)
      end
      if entry.distribution_paused?
        entry.deliveries.where(status: 'pending').update_all(status: 'cancelled', error_message: 'report_pause', updated_at: Time.current)
      end
      report
    end
  end

  def self.resolve!(report:, reviewer:, status:, resolution:)
    raise SecurityError, 'curator review required' unless reviewer.curator?
    raise ArgumentError, 'a report must be resolved or dismissed' unless %w[resolved dismissed].include?(status)
    raise ArgumentError, 'a resolution is required' if resolution.to_s.strip.empty?
    report.shit_entry.with_lock do
      report.lock!
      return report unless report.status == 'open'
      report.update!(status: status, reviewer: reviewer, resolution: resolution, reviewed_at: Time.current)
      AuditLog.create!(shit_entry: report.shit_entry, user: reviewer, category: 'report', action: status,
        details: { report_id: report.id, resolution: resolution })
      # Closing a report records a resolution only. Resuming distribution is
      # a separate audited review, even when the remaining report count is low.
      report
    end
  end
end
