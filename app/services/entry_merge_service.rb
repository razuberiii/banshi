class EntryMergeService
  def self.merge!(source:,target:,user:,reason:)
    raise ArgumentError,'需要馆务权限' unless user.curator?
    raise ArgumentError,'不能合并同一条目' if source==target
    raise ArgumentError,'已经合并的条目不能再次操作' if source.merged_into_id || target.merged_into_id
    raise ArgumentError,'请先结算两条内容的试吃' if TrialRun.active.where(shit_entry_id:[source.id,target.id]).exists?
    EntryMerge.transaction do
      ShitEntry.where(id:[source.id,target.id]).order(:id).lock.load
      snapshot={occurrences:source.shit_occurrences.pluck(:id),candidates:source.candidates.pluck(:id),timeline:source.timeline_events.pluck(:id),source_level:source.level}
      merge=EntryMerge.create!(source:source,target:target,user:user,reason:reason,snapshot:snapshot)
      source.shit_occurrences.update_all(shit_entry_id:target.id)
      source.candidates.update_all(shit_entry_id:target.id)
      source.timeline_events.update_all(shit_entry_id:target.id)
      source.update!(merged_into:target,distribution_paused:true)
      level=[source.safety_level,target.safety_level].max_by { |l| %w[GREEN YELLOW RED].index(l) }
      SafetyEvaluator.mark!(entry:target,level:level,tags:(source.safety_tags+target.safety_tags).uniq,visibility:level=='RED' ? 'hidden' : target.visibility,reason:"合并继承：#{reason}",user:user,source:'inheritance')
      EntryStatsRefresh.call(target)
      AuditLog.create!(user:user,shit_entry:target,category:'duplicate',action:'merge',details:{merge_id:merge.id,source_sid:source.sid})
      merge
    end
  end
  def self.revert!(merge:,user:)
    raise ArgumentError,'需要馆务权限' unless user.curator?
    merge.with_lock do
      raise ArgumentError,'此合并已撤销' if merge.reverted_at
      source=merge.source;target=merge.target
      ShitOccurrence.where(id:merge.snapshot['occurrences'],shit_entry:target).update_all(shit_entry_id:source.id)
      Candidate.where(id:merge.snapshot['candidates'],shit_entry:target).update_all(shit_entry_id:source.id)
      TimelineEvent.where(id:merge.snapshot['timeline'],shit_entry:target).update_all(shit_entry_id:source.id)
      source.update!(merged_into:nil,level:merge.snapshot['source_level'])
      merge.update!(reverted_at:Time.current)
      [source,target].each { |entry|EntryStatsRefresh.call(entry) }
      # Safety decisions are deliberately not downgraded by an undo operation.
      AuditLog.create!(user:user,shit_entry:source,category:'duplicate',action:'split',details:{merge_id:merge.id})
    end
  end
end
