class EntriesController < ApplicationController
  before_action :require_login,only:[:rate,:favorite]
  def index
    query=EntryQuery.call(params)
    @total=query.count
    @page=page_number
    @entries=query.offset((@page-1)*AppConfig.system.page_size).limit(AppConfig.system.page_size)
    @groups=Group.public_archives.order(:public_name)
  end
  def show
    @entry=ShitEntry.find_by!(sid:params[:sid])
    return redirect_to(entry_path(@entry.merged_into),status: :moved_permanently) if @entry.merged_into_id && @entry.merged_into.public?
    raise ActiveRecord::RecordNotFound unless @entry.public? || current_user&.curator?
    @occurrences=@entry.shit_occurrences.where(group_id:Group.public_archives.select(:id)).includes(:group,:transporter).order(:occurred_at)
    @timeline=@entry.timeline_events.public_associations.includes(:group,:transporter)
    @trial=@entry.trial_runs.order(created_at: :desc).first
    @related=ShitEntry.publicly_visible.where(first_group:@entry.first_group).where.not(id:@entry.id).limit(3)
    @matches=DuplicateMatch.where(content:@entry.content,status:'possible').includes(:shit_entry).select { |m| m.shit_entry.public? }
    @ratings=@entry.web_ratings.group(:reaction).count
    @my_ratings=signed_in? ? @entry.web_ratings.where(user:current_user).pluck(:reaction) : []
  end
  def random
    query=ShitEntry.publicly_visible
    entry=query.offset(rand([query.count,1].max)).first
    entry ? redirect_to(entry_path(entry)) : redirect_to(entries_path,notice:'还没有可公开的馆藏。')
  end
  def timeline
    @page=page_number
    scope=TimelineEvent.public_associations.where(shit_entry_id:ShitEntry.publicly_visible.select(:id)).includes(:shit_entry,:group).order(occurred_at: :desc)
    @total=scope.count;@events=scope.offset((@page-1)*30).limit(30)
  end
  def rate
    return head :not_found unless AppConfig.features.web_rating
    entry=ShitEntry.publicly_visible.find_by!(sid:params[:sid])
    reaction=params[:reaction].to_s
    return head :unprocessable_entity unless WebRating::REACTIONS.include?(reaction)
    current_user.with_lock do
      rating=entry.web_ratings.find_by(user:current_user,reaction:reaction)
      rating ? rating.destroy! : entry.web_ratings.create!(user:current_user,reaction:reaction)
    end
    redirect_to entry_path(entry),notice:'馆藏评价已更新。'
  end
  def favorite
    entry=ShitEntry.publicly_visible.find_by!(sid:params[:sid])
    current_user.with_lock do
      existing=current_user.favorites.find_by(shit_entry:entry)
      existing ? existing.destroy! : current_user.favorites.create!(shit_entry:entry)
    end
    redirect_to entry_path(entry),notice:'收藏夹已更新。'
  end
end
