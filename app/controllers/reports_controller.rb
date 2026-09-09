class ReportsController < ApplicationController
  before_action :require_login
  before_action { @entry=ShitEntry.publicly_visible.find_by!(sid:params[:entry_sid] || params[:entry_id]) }
  def new = @report=Report.new
  def create
    @report=ReportService.create!(entry:@entry,user:current_user,reason:params.dig(:report,:reason),details:params.dig(:report,:details))
    redirect_to profile_path(current_user),notice:'举报已记录，馆务会保留处理结果。'
  rescue ActiveRecord::RecordInvalid=>e
    @report=e.record;render :new,status: :unprocessable_entity
  rescue ActiveRecord::RecordNotUnique
    redirect_to entry_path(@entry),alert:'你已经举报过这条内容，正在等待处理。'
  end
end
