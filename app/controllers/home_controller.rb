class HomeController < ApplicationController
  def index
    public_entries = ShitEntry.publicly_visible
    @counts = {entries: public_entries.count, groups: Group.listed.count, natural: public_entries.sum(:natural_count)}
    @active = public_entries.where(level: %w[NORMAL HOT CLASSIC], distribution_paused: false)
      .where(id: Delivery.where(status: 'sent').where('sent_at > ?', 7.days.ago).select(:shit_entry_id))
      .order(updated_at: :desc).limit(6)
    @fresh = EntryQuery.call({}).limit(6)
    @natural = public_entries.where('natural_count > 1').order(last_natural_at: :desc).limit(4)
    @revivals = EntryQuery.call(sort: 'revivals').limit(3)
    @trials = TrialRun.where(shit_entry_id: public_entries.select(:id), status: 'running').includes(:shit_entry).limit(3)
  end
end
