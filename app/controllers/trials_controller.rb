class TrialsController < ApplicationController
  def index
    @runs=TrialRun.where(shit_entry_id:ShitEntry.publicly_visible.select(:id)).includes(:shit_entry,:trial_result,:trial_deliveries).order(created_at: :desc).limit(24)
  end
  def show
    @run=TrialRun.where(shit_entry_id:ShitEntry.publicly_visible.select(:id)).includes(trial_deliveries: :group).find(params[:id])
    @entry=@run.shit_entry
    @seats=@run.trial_deliveries.where(group_id:Group.public_archives.select(:id)).includes(:group,:delivery)
  end
end
