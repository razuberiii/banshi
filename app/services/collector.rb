class Collector
  def self.collect(message:)
    return unless message.source == 'NATURAL' && message.bot_account_id.nil?
    return unless message.group.can_collect? && message.content && %w[image forward].include?(message.content.kind)

    created = false
    candidate = message.with_lock do
      existing = Candidate.find_by(message_id: message.id)
      next existing if existing
      created = true
      Candidate.create!(message: message, group: message.group, transporter: message.transporter,
        content: message.content, expires_at: message.sent_at + AppConfig.candidate.ttl,
        reputation_snapshot: message.transporter&.reputation_score || 0.5)
    end
    DomainLog.emit('candidate.created', candidate_id: candidate.id) if created
    CandidateEvaluator.call(candidate: candidate)
    CandidateExpireJob.set(wait_until: candidate.expires_at).perform_later(candidate.id) if candidate.pending?
    ReputationRefreshJob.perform_later(candidate.transporter_id) if created && candidate.pending? && candidate.transporter_id
    candidate
  end
end
