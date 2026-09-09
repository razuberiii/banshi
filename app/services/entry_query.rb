class EntryQuery
  SORTS={'latest'=>'最新出土','hot'=>'正在热门','classic'=>'馆藏经典','fastest'=>'传播最快','natural'=>'自然搬运最多','revivals'=>'复活最多','trial'=>'抢先试吃','archived'=>'仅存档'}.freeze
  def self.call(params)
    q=ShitEntry.publicly_visible.includes(:first_group,:first_transporter,content: :assets)
    text=params[:q].to_s.strip.first(120)
    if text.present?
      like="%#{ActiveRecord::Base.sanitize_sql_like(text)}%"
      q=q.left_joins(:first_transporter).where("shit_entries.sid ILIKE :q OR shit_entries.title ILIKE :q OR shit_entries.summary ILIKE :q OR (CASE WHEN groups.anonymous THEN groups.anonymous_name ELSE groups.public_name END) ILIKE :q OR (groups.hide_members = false AND transporters.public_profile = true AND transporters.display_name ILIKE :q) OR array_to_string(shit_entries.safety_tags, ' ') ILIKE :q",q:like)
    end
    if params[:group].present?
      group=Group.public_archives.find_by(slug:params[:group]);q=group ? q.where(first_group:group) : q.none
    end
    q=q.where('shit_entries.safety_tags @> ARRAY[?]::varchar[]',params[:tag]) if AppConfig.safety.tags.include?(params[:tag])
    q=q.where(level:params[:level]) if ShitEntry::LEVELS.include?(params[:level])
    q=q.where(safety_level:params[:safety]) if %w[GREEN YELLOW].include?(params[:safety])
    [:from,:to].each do |bound|
      next unless params[bound].present?
      begin
        date=Date.iso8601(params[bound]);q=q.where("shit_entries.first_seen_at #{bound==:from ? '>=' : '<'} ?",bound==:from ? date.beginning_of_day : (date+1).beginning_of_day)
      rescue Date::Error
        q=q.none
      end
    end
    case params[:sort]
    when 'hot' then q.where(level:%w[HOT NORMAL]).order(distribution_score: :desc)
    when 'classic' then q.where(level:'CLASSIC').order(natural_count: :desc)
    when 'fastest' then q.order(Arel.sql("(SELECT COUNT(DISTINCT group_id) FROM shit_occurrences o WHERE o.shit_entry_id=shit_entries.id AND o.occurred_at >= CURRENT_TIMESTAMP - INTERVAL '#{AppConfig.leaderboard.period.to_i} seconds') DESC"))
    when 'natural' then q.order(natural_count: :desc)
    when 'revivals' then q.where('revival_count > 0').order(last_natural_at: :desc)
    when 'trial' then q.where(level:'TRIAL').order(first_seen_at: :desc)
    when 'archived' then q.where(level:'ARCHIVED').order(first_seen_at: :desc)
    else q.order(first_seen_at: :desc)
    end
  end
end
