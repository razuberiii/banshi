class ArchivePeriodMetrics
  def self.call(now:Time.current)
    window=(now-AppConfig.leaderboard.period)..now
    public_ids=ShitEntry.publicly_visible.select(:id)
    appearances=ShitOccurrence.where(shit_entry_id:public_ids,occurred_at:window)
    {
      reach:appearances.group(:shit_entry_id).distinct.count(:group_id),
      natural:appearances.where(source:'NATURAL').group(:shit_entry_id).count,
      discoveries:Candidate.where(status:'accepted',shit_entry_id:public_ids,evaluated_at:window).group(:transporter_id).count
    }
  end
end
