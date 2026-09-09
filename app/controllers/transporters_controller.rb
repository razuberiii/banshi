class TransportersController < ApplicationController
  def index
    @page=page_number
    @transporters=Transporter.public_profiles.order(natural_count: :desc)
    @total=@transporters.count
    @transporters=@transporters.offset((@page-1)*24).limit(24)
  end
  def show
    @transporter=Transporter.public_profiles.find_by!(public_id:params[:public_id])
    @entries=ShitEntry.publicly_visible.where(first_transporter:@transporter,groups:{hide_members:false}).order(natural_count: :desc).limit(12)
    @occurrences=@transporter.shit_occurrences.joins(:group).where(groups:{visibility:'public',hide_members:false},shit_entry_id:ShitEntry.publicly_visible.select(:id)).includes(:shit_entry,:group).order(occurred_at: :desc).limit(20)
  end
end
