class SimulationProcessor
  ACTIONS={'image'=>'群 A 发来一张图片','forward'=>'群 B 发来合并转发','replies'=>'3 位群友回复','reaction'=>'群友添加 💩','evaluate'=>'结束候选观察','approve'=>'审核安全示例并试吃','dispatch'=>'送到虚拟试吃群','feedback'=>'试吃群给出反馈','finish'=>'结算这轮试吃','distribute'=>'安排普通传播','repeat'=>'另一个群自然复读','revive'=>'90 天后再次出土','claim'=>'模拟群认领'}.freeze
  def self.call(action)
    action.with_lock do
      return if action.status=='done'
      raise ArgumentError,'模拟环境未开启' unless AppConfig.demo.enabled
      action.update!(status:'running')
      run=action.simulation_run;run.lock!
      result=new(run,action).call
      action.update!(status:'done',result:result)
    end
  rescue StandardError=>e
    action.update!(status:'failed',result:e.message.to_s.first(500))
    DomainLog.error(e,context:'simulation',simulation_action_id:action.id)
  end
  def initialize(run,action) = (@run,@action,@now=run,action,run.clock_at)
  def call
    params=@action.parameters
    groups=Group.joins(:group_bot_memberships).where(group_bot_memberships:{active:true}).distinct.order(:id).to_a
    origin=groups.first
    people=Transporter.order(:id).limit(36).to_a
    key="simulation-#{@action.id}"
    case @action.action_name
    when 'image','forward'
      @now=Time.current
      group=@action.action_name=='image' ? groups.first : groups.second
      env=FakeQQEnvironment.new(group:group,transporter:people.first,at:@now,key:key)
      if @action.action_name=='image'
        asset=DemoFixtures.fresh_asset(index:1000+@action.id)
        event=env.send_image(asset:asset)
      else
        content=DemoFixtures.forward_content(index:1000+@action.id)
        event=env.send_forward(content:content)
      end
      message=Message.find_by!(internal_event:event)
      @run.update!(clock_at:@now,state:{candidate_id:message.candidate&.id})
      '候选已进入观察窗口，机器人在群内保持安静。'
    when 'replies'
      candidate=require_candidate
      people[1..3].each_with_index { |p,i|FakeQQEnvironment.new(group:candidate.group,transporter:p,at:@now+i.seconds,key:"#{key}-#{i}").reply(target:candidate.message) }
      CandidateEvaluator.call(candidate:candidate,now:@now)
      '3 名不同的群友产生了直接回复。'
    when 'reaction'
      candidate=require_candidate
      FakeQQEnvironment.new(group:candidate.group,transporter:people[4],at:@now+5.seconds,key:key).react(target:candidate.message,emoji:AppConfig.trial.reaction_good)
      CandidateEvaluator.call(candidate:candidate,now:@now)
      '已添加一条可撤销的 💩 Reaction。'
    when 'evaluate'
      candidate=require_candidate
      @now=[@now,candidate.expires_at+1.second].max
      CandidateEvaluator.call(candidate:candidate,now:@now)
      @run.update!(clock_at:@now,state:@run.state.merge('entry_id'=>candidate.reload.shit_entry_id))
      "候选结算：#{candidate.status}。#{candidate.shit_entry&.sid}"
    when 'approve'
      entry=require_entry
      SafetyEvaluator.mark!(entry:entry,level:'GREEN',tags:[],visibility:'public',reason:'馆务确认：项目原创、安全虚构示例',user:@run.user,source:'manual')
      TrialDispatcher.call(entry:entry,now:@now)
      '安全审核已通过，开始为这件馆藏寻找试吃席位。'
    when 'dispatch'
      entry=require_entry
      TrialDispatcher.call(entry:entry,now:@now)
      entry.deliveries.where(status:'pending').find_each { |d|Distributor.deliver!(delivery:d,now:@now) }
      "已向 #{entry.deliveries.where(kind:'BOT_TRIAL',status:'sent').count} 个虚拟群投放。"
    when 'feedback'
      run=require_trial
      run.trial_deliveries.includes(:delivery,:group).each_with_index do |seat,i|
        next unless seat.delivery.status=='sent'
        next if i==run.trial_deliveries.count-1 # Deliberately retain one silent group.
        [AppConfig.trial.reaction_good,AppConfig.trial.reaction_funny].each_with_index do |emoji,j|
          FakeQQEnvironment.new(group:seat.group,transporter:people[5+i*3+j],at:@now+1.minute,key:"#{key}-#{i}-#{j}").react(target:seat.delivery.message,emoji:emoji)
        end
        FakeQQEnvironment.new(group:seat.group,transporter:people[7+i*3],at:@now+2.minutes,key:"#{key}-reply-#{i}").reply(target:seat.delivery.message)
      end
      first=run.trial_deliveries.first
      FakeQQEnvironment.new(group:first.group,transporter:people.last,at:@now+3.minutes,key:"#{key}-bad").react(target:first.delivery.message,emoji:AppConfig.trial.reaction_bad) if first&.delivery&.message
      '已记录 💩 / 😂 / 🥱，并保留一个没有反应的群。'
    when 'finish'
      run=require_trial;@now=[@now,run.ends_at+1.second].max
      TrialEvaluator.call(run:run,now:@now);@run.update!(clock_at:@now)
      "试吃结果：#{run.reload.trial_result&.verdict}；传播等级：#{run.shit_entry.reload.level}。"
    when 'distribute'
      entry=require_entry
      Distributor.call(entry:entry,now:@now).each { |d|Distributor.deliver!(delivery:d,now:@now) }
      "普通传播记录已更新，累计机器人投放 #{entry.reload.bot_count} 次。"
    when 'repeat','revive'
      entry=require_entry
      @now += @action.action_name=='revive' ? [AppConfig.classic.min_lifespan,AppConfig.classic.revival_gap+1.day].max : 3.days
      candidates=groups.select(&:can_collect?)
      repetitions=@action.action_name=='revive' ? AppConfig.classic.min_natural_occurrences : 1
      repetitions.times do |i|
        group=candidates[(i+3)%candidates.length]
        env=FakeQQEnvironment.new(group:group,transporter:people[(i+8)%people.length],at:@now+i.hours,key:"#{key}-#{i}")
        entry.content.forward? ? env.send_forward(content:entry.content) : env.send_image(asset:entry.content.assets.first)
      end
      ClassicEvaluator.call(entry.reload,now:@now+repetitions.hours)
      @run.update!(clock_at:@now+repetitions.hours)
      "自然复读沿用 #{entry.sid}；现为 #{entry.reload.level}，#{entry.natural_count} 次自然搬运。"
    when 'claim'
      group=Group.find(params.fetch('group_id'));person=Transporter.find(params.fetch('transporter_id'))
      digest=params['token_digest'] || Digest::SHA256.hexdigest(params.fetch('token'))
      adapter=Adapters::Registry.for(group.available_connection)
      raise ArgumentError,'群认领模拟仅允许 Fake 连接' unless adapter.is_a?(Adapters::FakeNapCatAdapter)
      ClaimVerifier.call(digest:digest,group:group,sender_external_id:person.external_id,adapter:adapter,mentions_bot:true)
      claim=ClaimToken.find_by(token_digest:digest)
      claim&.used_at ? "认领成功：#{group.display_name}。" : '认领未通过：请检查验证码有效期，以及发送者是否为群主或管理员。'
    else raise ArgumentError,'未知模拟操作'
    end
  end
  private
  def require_candidate = @run.candidate || raise(ArgumentError,'请先发送一张图片或合并转发。')
  def require_entry = @run.entry || raise(ArgumentError,'请先让候选满足阈值并完成观察。')
  def require_trial = require_entry.trial_runs.order(:id).last || raise(ArgumentError,'请先完成安全审核并进入试吃。')
end
