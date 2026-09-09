# Original, fictional archive histories. Counts, timelines and trial results are
# derived from their underlying occurrences/interactions, never display constants.
class ArchiveSeed
  VERSION = 'v0.1-original-archive'.freeze
  GROUP_NAMES = %w[周一精神互助会 下班后考古小组 互联网标本室 无效沟通研究所
    碳基生物休息站 最终版_v9 夜班猫猫观察局 今日不宜开会
    电子榨菜补给站 河边摸鱼联合会 群聊民俗研究所 人间废话电台
    已读空气俱乐部 抽象内容实验室 下水道勘探分队 周五提前放学
    低电量自救中心 一口一个好消息 互联网地层学会 老图修复工作室
    偶尔营业的食堂 匿名第七观察站 只公开数字的群馆 不对外开放的群馆].freeze
  PEOPLE = %w[饭后散步的猫 最终版保管员 星期五信徒 老图修复师 摸鱼气象员
    芋泥档案员 路过的土豆 空气已读 阿纸 椅子观察家 半杯乌龙 不加班的小熊
    地铁漫游者 蜗牛快递员 胡说八道研究员 电量百分之三 存图但不看
    一口榨菜 小小考古家 从不早睡 随机路人甲 冒泡的水壶 周末预言家
    河边发呆 黄色便签 厕所守望员 板凳鉴赏师 下班铃声 猫毛收藏家
    云端摸鱼王 小声复读 凌晨放映员 快乐文件夹 安静的感叹号 最后一条了 明天再改].freeze

  def self.call = new.call
  def call
    return puts('Fictional archive already installed; existing histories preserved.') if AuditLog.exists?(category:'seed',action:VERSION)
    raise 'Refusing to seed a nonempty archive. Use a separate development database.' if ShitEntry.exists?
    previous=ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter=:test
    @now=Time.current.change(usec:0)
    ActiveRecord::Base.transaction do
      identities
      @entries=Array.new(120) { |i| specimen(i) }
      candidate_examples
      moderation_examples
      @people.each { |person| ReputationCalculator.call(person) }
      @groups.each { |group| GroupStatsRefresh.call(group) }
      LeaderboardRefresh.call
      @entries.select(&:public?).first(18).each_with_index do |entry,i|
        Favorite.create!(user:@visitors[i%3],shit_entry:entry)
        WebRating.create!(user:@visitors[i%3],shit_entry:entry,reaction:%w[💩 😂 🏛️ 🥱][i%4])
      end
      AuditLog.create!(category:'seed',action:VERSION,details:{groups:@groups.size,transporters:@people.size,entries:@entries.size,fictional:true})
    end
    puts "Archive ready: #{Group.count} groups, #{Transporter.count} transporters, #{ShitEntry.count} entries, #{ShitOccurrence.count} occurrences."
    puts "Demo login: #{AppConfig.demo.email} (or use the demo login button)."
  ensure
    ActiveJob::Base.queue_adapter=previous if previous
  end

  private
  def identities
    @curator=User.create!(email:AppConfig.demo.email,password:AppConfig.demo.password,display_name:'值班馆员',site_role:'curator')
    @visitors=3.times.map { |i| User.create!(email:"visitor#{i+1}@example.test",password:AppConfig.demo.password,display_name:['周末逛馆人','小口试吃员','路过收藏家'][i]) }
    @bots=2.times.map { |i| BotAccount.create!(external_id:"fake-bot-#{i+1}",name:"搬运员 #{('A'.ord+i).chr}") }
    @connections=@bots.map { |bot| BotConnection.create!(bot_account:bot,name:"#{bot.name} · Fake NapCat",adapter:'fake',status:'online',capabilities:{group_reactions:true,member_roles:true,forward_nodes:true,fictional:true}) }
    @people=PEOPLE.each_with_index.map { |name,i| Transporter.create!(external_id:"fake-person-#{format('%03d',i+1)}",display_name:name,public_profile:true) }
    @groups=GROUP_NAMES.each_with_index.map do |name,i|
      group=Group.create!(external_id:"fake-group-#{format('%03d',i+1)}",slug:"museum-#{format('%02d',i+1)}",public_name:name,anonymous_name:"匿名群馆 #{format('%02d',i+1)}",
        anonymous:i==21,hide_members:i>=21,visibility:i==23 ? 'hidden' : i==22 ? 'statistics' : 'public',
        description:['这里保存我们不经意间留下的互联网碎片。群聊照常，考古继续。','一个对废话很认真的地方。没有专家，只有路过的群友。','老图不是过期了，只是在等下一次有人想起。'][i%3],
        trial_preference:i%5==4 ? 'OPT_OUT' : i%4==3 ? 'FALLBACK' : 'OPT_IN',daily_limit:4+i%5,cooldown_minutes:45+(i%3)*15,
        accepted_tags:i%4==0 ? %w[GROTESQUE HARASSMENT OTHER_SENSITIVE] : [],accept_archaeology:i.even?,
        joined_at:@now-(i<20 ? 240-i*7 : 24-i).days)
      @bots.each_with_index do |bot,j|
        next unless i<4 || (i%2)==j
        GroupBotMembership.create!(group:group,bot_account:bot,card:bot.name,active:true,joined_at:group.joined_at)
      end
      @people.each_with_index { |person,j| GroupMember.create!(group:group,transporter:person,role:j==0 ? 'owner' : j==1 ? 'admin' : 'member',display_name:person.display_name) }
      TimelineEvent.create!(group:group,event_type:'group_joined',label:'群馆加入搬运网络',occurred_at:group.joined_at,dedupe_key:"seed:group:#{i}")
      group
    end
    GroupManagement.create!(group:@groups.first,user:@curator,verified_role:'owner',verified_at:@now-10.days)
    GroupManagement.create!(group:@groups.second,user:@visitors.first,verified_role:'admin',verified_at:@now-5.days)
  end

  def specimen(i)
    klassic=i<15
    old=i>=15 && i<28
    live=i>=114 && i<117
    at=if klassic then @now-(180+i*9).days
      elsif old then @now-(70+i).days
      elsif i>=110 then @now-(i==119 ? 40 : (120-i)*42).minutes
      else @now-(110-i).hours-2.hours end
    source_groups=@groups.select(&:can_collect?)
    group=source_groups[i%source_groups.length]
    person=@people[i%@people.length]
    title=DemoFixtures::TITLES[i%DemoFixtures::TITLES.length]
    title="#{title} · 切片 #{i/20+1}" if i>=20
    content=fixture_content(i,title,at)
    entry=ShitEntry.create!(content:content,first_group:group,first_transporter:person,title:title,
      summary:'项目原创虚构标本。档案中的自然搬运、试吃反馈和时间线来自下方可追溯的事件记录。',
      first_seen_at:at,last_natural_at:at,safety_level:'GREEN',visibility:'public')
    first=natural(entry,group,person,at,"#{i}-first")
    3.times { |j| interaction(first,@people[(i+j+1)%36],'reply','',at+(j+1).minutes) }
    candidate=Candidate.create!(message:first,group:group,transporter:person,content:content,shit_entry:entry,status:'accepted',expires_at:at+AppConfig.candidate.ttl,
      evaluated_at:at+AppConfig.candidate.ttl,score:6,reputation_snapshot:0.5,decision_reason:'3 名独立用户回复，观察窗口结束后建档',
      rule_results:{reply_users:3,unique_users:3,base_score:content.forward? ? AppConfig.candidate.forward_base : 0,evidence_score:3*AppConfig.candidate.reply_weight,score:3*AppConfig.candidate.reply_weight,minimum_score:AppConfig.candidate.min_score,eligible:true})
    TimelineEvent.create!(shit_entry:entry,group:group,event_type:'collected',label:'候选正式入库',occurred_at:candidate.evaluated_at,details:candidate.rule_results,dedupe_key:"candidate:#{candidate.id}:accepted")
    SafetyDecision.create!(shit_entry:entry,user:@curator,level:'GREEN',tags:[],source:'manual',rule:'original_safe_fixture',reason:'已审核：项目自带原创虚构内容',visibility:'public',decided_at:candidate.evaluated_at+1.minute)
    TimelineEvent.create!(shit_entry:entry,event_type:'safety_review',label:'安全审核通过',occurred_at:candidate.evaluated_at+1.minute,details:{level:'GREEN'},dedupe_key:"seed:safety:#{i}")
    if i%9!=8 || live
      trial_at=live ? @now-12.minutes : at+AppConfig.candidate.ttl+2.minutes
      trial(entry,i,trial_at,live:live)
    end
    repetitions=klassic ? 9+i%8 : old ? 3+i%4 : i%8
    repetitions.times do |j|
      time=if klassic
        j<3 ? at+(j+1).days : @now-(repetitions-j).hours
      elsif old
        j==0 ? at+1.day : @now-(repetitions-j).hours
      else
        [at+(j+1)*37.minutes,@now-2.minutes].min
      end
      natural(entry,source_groups[(i+j+2)%source_groups.length],@people[(i+j+5)%36],time,"#{i}-repeat-#{j}")
    end
    EntryStatsRefresh.call(entry)
    LevelEvaluator.call(entry,now:@now)
    ClassicEvaluator.call(entry,now:@now)
    # Additional genuine bot source histories remain separate from natural counts.
    if %w[NORMAL HOT CLASSIC].include?(entry.reload.level)
      eligible=@groups.select { |g| g.can_distribute? && !entry.shit_occurrences.exists?(group:g) }
      eligible.first(1+i%3).each_with_index do |target,j|
        bot_delivery(entry,target,klassic ? 'BOT_CLASSIC' : 'BOT_DISTRIBUTION',@now-(28+j+i%7).hours,key:"normal-#{i}-#{j}")
      end
    end
    puts "Seeded #{i+1}/120 specimens" if (i+1)%20==0
    entry.reload
  end

  def fixture_content(i,title,at)
    # Include the fixture identity in the forward text, so repeated templates are
    # still distinct conversations and are stable under real duplicate hashing.
    if i%5==2
      lines=DemoFixtures::LINES[i%DemoFixtures::LINES.size]+["标本 #{format('%03d',i+1)}：#{title}"]
      fingerprint=Digest::SHA256.hexdigest(JSON.generate(['forward',[],lines]))
      content=Content.create!(kind:'forward',fingerprint:fingerprint,metadata:{fictional:true,fixture_index:i})
      lines.each_with_index { |line,j| content.forward_nodes.create!(position:j,body:line,display_name:'匿名群友',sent_at:at+j.minutes) }
    else
      path=Rails.root.join('db','fixtures','media',format('specimen-%03d.png',i))
      FileUtils.mkdir_p(path.dirname)
      File.binwrite(path,DemoFixtures.image_bytes(index:i,title:title)) unless path.exist?
      asset=Media::ContentIngestor.store(bytes:File.binread(path))
      content=Content.create!(kind:'image',fingerprint:Digest::SHA256.hexdigest(JSON.generate(['image',[asset.sha256],[]])),metadata:{fictional:true,fixture_index:i})
      content.attachments.create!(asset:asset,position:0)
    end
    content
  end

  def natural(entry,group,person,at,key)
    message=Message.create!(group:group,transporter:person,content:entry.content,external_id:"seed-natural-#{key}",kind:entry.content.kind,source:'NATURAL',sent_at:at)
    OccurrenceRecorder.call(entry:entry,message:message,duplicate_matched:!key.end_with?('first'),confidence:1.0)
    message
  end

  def interaction(message,person,kind,emoji,at)
    Interaction.create!(group:message.group,transporter:person,message:message,target_external_id:message.external_id,kind:kind,reaction:emoji,active:true,occurred_at:at,identity_key:"seed:#{message.id}:#{person.id}:#{kind}:#{emoji}")
  end

  def bot_delivery(entry,group,kind,at,key:,run:nil)
    connection=group.available_connection
    message=Message.create!(group:group,bot_account:connection.bot_account,content:entry.content,external_id:"seed-bot-#{key}",kind:entry.content.kind,source:kind,sent_at:at)
    delivery=Delivery.create!(shit_entry:entry,group:group,bot_connection:connection,trial_run:run,message:message,kind:kind,status:'sent',idempotency_key:"seed:#{key}",external_message_id:message.external_id,sent_at:at,
      decision:{reason:'fictional_historical_receipt',reserved_at:at.iso8601},created_at:at)
    OccurrenceRecorder.call(entry:entry,message:message,source:kind,delivery:delivery,trial_run:run)
    entry.update!(first_distributed_at:[entry.first_distributed_at,at].compact.min)
    delivery
  end

  def trial(entry,i,at,live:)
    run=TrialRun.create!(shit_entry:entry,status:'running',started_at:at,ends_at:at+AppConfig.trial.duration,created_at:at,explanation:{minimum_groups:3,fixture:true})
    entry.update!(level:'TRIAL')
    TimelineEvent.create!(shit_entry:entry,event_type:'trial_started',label:'进入抢先试吃',occurred_at:at,dedupe_key:"trial:#{run.id}:started")
    pool=@groups.select { |g| g.can_distribute? && g.trial_preference!='OPT_OUT' && g!=entry.first_group }
    pool.rotate(i%pool.length).first(3+i%3).each_with_index do |group,j|
      delivery=bot_delivery(entry,group,'BOT_TRIAL',at,key:"trial-#{i}-#{j}",run:run)
      TrialDelivery.create!(trial_run:run,group:group,delivery:delivery)
      next if i%11==0 || j==4 # Silent seats are unknown, including some entire trials.
      count=i%4==0 ? 4 : 2
      count.times do |k|
        person=@people[(i+j*5+k+6)%36]
        emoji=i%7==0 ? AppConfig.trial.reaction_bad : k.even? ? AppConfig.trial.reaction_good : AppConfig.trial.reaction_funny
        interaction(delivery.message,person,'reaction',emoji,at+(k+1).minutes)
      end
      interaction(delivery.message,@people[(i+j*5+12)%36],'reply','',at+8.minutes) unless i%7==0
    end
    TrialEvaluator.call(run:run,now:at+AppConfig.trial.duration+1.second) unless live
    run.trial_result&.update_columns(created_at:at+AppConfig.trial.duration)
  end

  def candidate_examples
    8.times do |i|
      content=fixture_content(150+i,"尚在观察的标本 #{i+1}",@now)
      group=@groups[i%2];person=@people[(i+5)%36]
      at=@now-(i<4 ? 5 : 80).minutes
      message=Message.create!(group:group,transporter:person,content:content,external_id:"seed-candidate-#{i}",kind:content.kind,source:'NATURAL',sent_at:at)
      candidate=Collector.collect(message:message)
      CandidateEvaluator.call(candidate:candidate,now:@now)
    end
  end

  def moderation_examples
    @entries[103..105].each_with_index do |entry,i|
      SafetyEvaluator.mark!(entry:entry,level:'YELLOW',tags:[%w[GROTESQUE HARASSMENT OTHER_SENSITIVE][i]],visibility:'public',reason:'演示分类：实际资源均为安全虚构素材',user:@curator)
    end
    @entries[106..109].each { |entry| SafetyEvaluator.mark!(entry:entry,level:'RED',tags:[],visibility:'hidden',reason:'演示待审核状态；未判断的内容不自动传播',user:@curator) }
    @visitors.each { |visitor| ReportService.create!(entry:@entries[108],user:visitor,reason:'misclassification',details:'虚构举报示例，用于演示暂停与审核。') }
    ReportService.create!(entry:@entries[109],user:@visitors.first,reason:'privacy',details:'虚构隐私举报，不含任何真实个人信息。')
    resolved=ReportService.create!(entry:@entries[100],user:@visitors.last,reason:'other',details:'演示已处理的举报。')
    ReportService.resolve!(report:resolved,reviewer:@curator,status:'dismissed',resolution:'已确认是原创虚构截图，保留馆藏。')
    matches=0
    @entries.select { |entry| entry.content.image? }.combination(2).each do |source,target|
      left=source.content.assets.first&.phash;right=target.content.assets.first&.phash
      next unless left && right
      distance=Media::PerceptualHash.distance(left,right)
      next unless distance>AppConfig.duplicate.phash_threshold && distance<=AppConfig.duplicate.possible_threshold
      DuplicateMatch.create!(content:source.content,shit_entry:target,method:'phash',status:'possible',confidence:1-distance/64.0,distance:distance)
      matches+=1
      break if matches>=3
    end
  end
end
