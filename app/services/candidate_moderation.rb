# An explicit operator disposition. Collector itself never infers safety.
class CandidateModeration
  def self.call(candidate:,user:,status:,reason:)
    raise ArgumentError,'需要馆务权限' unless user.curator?
    raise ArgumentError,'请选择拒绝或安全隔离' unless %w[rejected unsafe].include?(status)
    raise ArgumentError,'请填写处理依据' if reason.to_s.strip.empty?
    candidate.with_lock do
      raise ArgumentError,'候选已完成判定' unless candidate.pending?
      candidate.update!(status:status,evaluated_at:Time.current,decision_reason:reason,
        rule_results:candidate.rule_results.merge('manual_disposition'=>status,'reviewer_id'=>user.id))
      candidate.content.assets.update_all(visibility:'hidden') if status=='unsafe'
      AuditLog.create!(user:user,group:candidate.group,category:status=='unsafe' ? 'safety' : 'collector',action:'candidate_disposition',details:{candidate_id:candidate.id,status:status,reason:reason})
      ReputationRefreshJob.perform_later(candidate.transporter_id) if candidate.transporter_id
    end
    candidate
  end
end
