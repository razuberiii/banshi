class GroupsController < ApplicationController
  before_action :require_login,only:[:edit,:update]
  before_action :load_group,only:[:show,:edit,:update]
  def index
    raise ActiveRecord::RecordNotFound unless AppConfig.features.public_groups
    @groups=Group.listed.order(joined_at: :desc)
    if params[:q].present?
      @groups=@groups.where("(CASE WHEN anonymous THEN anonymous_name ELSE public_name END) ILIKE ?","%#{Group.sanitize_sql_like(params[:q].to_s.first(80))}%")
    end
    @total=@groups.count;@page=page_number;@groups=@groups.offset((@page-1)*24).limit(24)
  end
  def show
    @stats=@group.stats
    if @group.public_archive? || current_user&.manages?(@group)
      @discoveries=ShitEntry.publicly_visible.where(first_group:@group)
      @representative=@discoveries.order(natural_count: :desc).first
      @recent=@discoveries.order(first_seen_at: :desc).limit(6)
      @classic=@discoveries.where(level:'CLASSIC').order(natural_count: :desc).limit(3)
      @consumed=ShitEntry.publicly_visible.where(id:@group.shit_occurrences.bot.select(:shit_entry_id)).limit(4)
      @repeat_counts=@group.shit_occurrences.natural.group(:shit_entry_id).count
      repeated=ShitEntry.publicly_visible.where(id:@repeat_counts.keys).index_by(&:id)
      @repeated=@repeat_counts.sort_by { |id,count| [-count,id] }.filter_map { |id,_| repeated[id] }.first(4)
      @exported=@discoveries.order(natural_group_count: :desc).limit(4)
      @timeline=@group.timeline_events.where(shit_entry_id:ShitEntry.publicly_visible.select(:id)).or(@group.timeline_events.where(shit_entry_id:nil)).order(occurred_at: :desc).includes(:shit_entry,:group).limit(20)
      @contributors=@group.transporters.public_profiles.order(natural_count: :desc).limit(6) unless @group.hide_members?
    end
  end
  def edit
    authorize_group!
  end
  def update
    return unless authorize_group!
    attributes=group_params
    attributes=attributes.merge(mode_event_at:Time.current,mode_event_id:nil) if attributes.key?(:mode)
    if @group.update(attributes)
      AuditLog.create!(user:current_user,group:@group,category:'group',action:'preferences_updated',details:{fields:group_params.keys})
      redirect_to group_path(@group),notice:'本群胃口已更新。平台安全限制始终生效。'
    else render :edit,status: :unprocessable_entity
    end
  end
  private
  def load_group
    @group=Group.find_by!(slug:params[:slug])
    raise ActiveRecord::RecordNotFound if (!AppConfig.features.public_groups || @group.visibility=='hidden') && !current_user&.manages?(@group)
  end
  def authorize_group!
    return true if current_user.manages?(@group)
    render plain:'你还没有这个群的管理权限。',status: :forbidden
    false
  end
  def group_params
    permitted = params.require(:group).permit(:public_name,:description,:mode,:trial_preference,:daily_limit,:cooldown_minutes,:collect_enabled,:distribute_enabled,:accept_hot,:accept_classic,:accept_archaeology,:anonymous,:visibility,:hide_members,accepted_tags:[])
    permitted[:accepted_tags] = Array(permitted[:accepted_tags]).reject(&:blank?) if permitted.key?(:accepted_tags)
    permitted
  end
end
