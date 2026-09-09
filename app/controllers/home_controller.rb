class HomeController < ApplicationController
  def index
    public_entries=ShitEntry.publicly_visible
    @counts={entries:public_entries.count,groups:Group.listed.count,natural:public_entries.sum(:natural_count)}
    @fresh=EntryQuery.call({}).where(first_seen_at:Time.current.beginning_of_day..Time.current).limit(6)
    @featured=EntryQuery.call(sort:'classic').first || @fresh.first
    @trials=TrialRun.joins(:shit_entry).where(shit_entry_id:public_entries.select(:id),status:'running').includes(:shit_entry).limit(3)
    @results=TrialResult.joins(trial_run: :shit_entry).where(trial_runs:{shit_entry_id:public_entries.select(:id)},created_at:Time.current.beginning_of_day..Time.current).order(created_at: :desc).limit(3)
    @period=ArchivePeriodMetrics.call
    @fastest=ranked_entries(public_entries,@period[:reach],4)
    @natural=ranked_entries(public_entries,@period[:natural],3)
    @revivals=EntryQuery.call(sort:'revivals').limit(3)
    @classic=EntryQuery.call(sort:'classic').limit(4)
    @archaeology=public_entries.where('shit_entries.first_seen_at < ?',90.days.ago).order(:id).offset(Date.current.yday % [public_entries.where('shit_entries.first_seen_at < ?',90.days.ago).count,1].max).first
    @new_classics=public_entries.where(level:'CLASSIC').order(classic_at: :desc).limit(3)
    @groups=AppConfig.features.public_groups ? Group.listed.order(joined_at: :desc).limit(4) : []
    ids=@period[:discoveries].sort_by { |id,count| [-count,id || 0] }.map(&:first).compact
    @leaders=Transporter.public_profiles.where(id:ids).index_by(&:id).values.sort_by { |person| -@period[:discoveries].fetch(person.id,0) }.first(3)
  end
  private
  def ranked_entries(scope,counts,limit)
    ids=counts.sort_by { |id,count| [-count,id] }.first(limit).map(&:first)
    records=scope.where(id:ids).index_by(&:id)
    ids.filter_map { |id| records[id] }
  end
end
