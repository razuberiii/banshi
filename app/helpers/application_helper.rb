module ApplicationHelper
  LEVEL_NAMES={'ARCHIVED'=>'仅存档','TRIAL'=>'抢先试吃','NORMAL'=>'正在传播','HOT'=>'热门','CLASSIC'=>'典藏'}.freeze
  TAG_NAMES={'GORE'=>'血腥','NSFW'=>'NSFW','GROTESQUE'=>'猎奇','HARASSMENT'=>'强烈辱骂','PRIVACY'=>'隐私风险','EXTREME'=>'极端内容','OTHER_SENSITIVE'=>'其他敏感'}.freeze
  def level_badge(entry)
    tag.span(LEVEL_NAMES.fetch(entry.level,entry.level),class:"badge level-#{entry.level.downcase}")
  end
  def safety_badge(entry)
    label={'GREEN'=>'已审核','YELLOW'=>'敏感标记','RED'=>'暂停传播'}.fetch(entry.safety_level)
    tag.span(label,class:"safety safety-#{entry.safety_level.downcase}")
  end
  def tag_name(key) = TAG_NAMES.fetch(key,key)
  def museum_time(time) = time&.in_time_zone&.strftime('%Y.%m.%d %H:%M') || '—'
  def museum_date(time) = time&.in_time_zone&.strftime('%Y.%m.%d') || '—'
  def short_number(number) = number_with_delimiter(number.to_i)
  def safe_group_name(group)
    return '未公开的群馆' unless group&.public_archive?
    group.display_name
  end
  def group_link(group)
    group&.public_archive? ? link_to(group.display_name,group_path(group)) : '未公开的群馆'
  end
  def transporter_link(person,group:nil)
    person && person.public_profile? && !group&.hide_members? ? link_to(person.display_name,transporter_path(person)) : '匿名搬运者'
  end
  def rate(value) = "#{(value.to_f*100).round}%"
  def page_count(total,size=AppConfig.system.page_size) = (total.to_f/size).ceil
  def empty_state(text='这里暂时还没有出土记录。') = tag.div(text,class:'empty-state')
  def trial_verdict(result)
    return '观察中' unless result
    {'passed'=>'试吃通过','failed'=>'暂不续杯','unknown'=>'沉默，仍是未知'}.fetch(result.verdict,result.verdict)
  end
end
