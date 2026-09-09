class HomeController < ApplicationController
  def index
    public_entries=ShitEntry.publicly_visible
    @counts={entries:public_entries.count,groups:Group.listed.count,natural:public_entries.sum(:natural_count)}
    @fresh=EntryQuery.call({}).limit(6)
    @featured=EntryQuery.call(sort:'classic').first || @fresh.first
    @trials=TrialRun.joins(:shit_entry).where(shit_entry_id:public_entries.select(:id),status:'running').includes(:shit_entry).limit(3)
    @results=TrialResult.joins(trial_run: :shit_entry).where(trial_runs:{shit_entry_id:public_entries.select(:id)}).order(created_at: :desc).limit(3)
    @fastest=EntryQuery.call(sort:'fastest').limit(4)
    @natural=EntryQuery.call(sort:'natural').limit(3)
    @revivals=EntryQuery.call(sort:'revivals').limit(3)
    @classic=EntryQuery.call(sort:'classic').limit(4)
    @archaeology=public_entries.where('shit_entries.first_seen_at < ?',90.days.ago).order(:id).offset(Date.current.yday % [public_entries.where('shit_entries.first_seen_at < ?',90.days.ago).count,1].max).first
    @new_classics=public_entries.where(level:'CLASSIC').order(classic_at: :desc).limit(3)
    @groups=AppConfig.features.public_groups ? Group.listed.order(joined_at: :desc).limit(4) : []
    @leaders=Transporter.public_profiles.order(accepted_count: :desc).limit(3)
  end
end
