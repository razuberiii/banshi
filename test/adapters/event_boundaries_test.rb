require_relative '../domain_helpers'

class EventBoundariesTest < ActiveSupport::TestCase
  include DomainHelpers

  def submit(payload, connection)
    Events::Ingestor.call(payload:payload,connection:connection,enqueue:false).first
  end

  def group_payload(group, connection, **attributes)
    {'post_type'=>'notice','self_id'=>connection.bot_account.external_id,'group_id'=>group.external_id,'time'=>Time.current.to_i}.merge(attributes.stringify_keys)
  end

  test 'short message ID conflicts retain separate evidence without overwriting history' do
    @group=domain_group;@connection=domain_bot(@group)
    payload={'post_type'=>'message','message_type'=>'group','self_id'=>@connection.bot_account.external_id,'group_id'=>@group.external_id,'user_id'=>'person-a','message_id'=>'same-short-id','time'=>Time.current.to_i,'message'=>[{'type'=>'text','data'=>{'text'=>'first'}}]}
    first=Events::Ingestor.call(payload:payload,connection:@connection,enqueue:false).first
    conflict=Events::Ingestor.call(payload:payload.merge('user_id'=>'person-b','time'=>payload['time']+10),connection:@connection,enqueue:false).first
    assert_equal 'person-a',first.reload.sender_external_id
    assert_equal 'ignored',conflict.status
    assert_equal 2,RawEvent.count
    assert AuditLog.exists?(category:'onebot',action:'message_id_conflict')
  end

  test 'failed processing rolls back business changes while retaining each attempt' do
    group=domain_group
    connection=domain_bot(group)
    event=submit(group_payload(group,connection,post_type:'message',message_type:'group',user_id:'poison-user',message_id:'poison-message',message:[{'type'=>'image','data'=>{'url'=>'http://forbidden.example/image'}}]),connection)
    AppConfig.with(jobs:{attempts:2}) do
      2.times do |index|
        assert_raises(ArgumentError) { Events::Processor.call(event.reload) }
        assert_equal index+1,event.reload.attempts
        assert_equal 'failed',event.status
        refute group.messages.exists?(external_id:'poison-message')
      end
      Events::Processor.call(event.reload)
      assert_equal 2,event.reload.attempts
    end
  end

  test 'claim is routed to the mentioned bot even when another bot observes it first' do
    group=domain_group
    observer=domain_bot(group)
    mentioned=domain_bot(group)
    person=domain_transporter
    GroupMember.create!(group:group,transporter:person,role:'admin')
    user=domain_user
    claim,token=ClaimIssuer.call(user:user)
    payload=group_payload(group,observer,post_type:'message',message_type:'group',user_id:person.external_id,message_id:'claim-multi-bot',message:[{'type'=>'at','data'=>{'qq'=>mentioned.bot_account.external_id}},{'type'=>'text','data'=>{'text'=>token}}])
    event=submit(payload,observer)
    Events::Processor.call(event)
    assert claim.reload.used_at
    assert user.manages?(group)
    refute_includes event.reload.metadata.to_json,token
    refute_includes event.raw_event.reload.payload.to_json,token
    refute_includes group.messages.find_by!(external_id:'claim-multi-bot').body,token
    second=submit(payload.merge('self_id'=>mentioned.bot_account.external_id),mentioned)
    assert_equal event.id,second.id
    Events::Processor.call(second)
    assert_equal 1,GroupManagement.where(group:group,user:user).count
  end

  test 'reaction ordering follows event time and ingestion order for equal seconds' do
    group=domain_group
    connection=domain_bot(group)
    actor=domain_transporter
    target=domain_message(group:group)
    now=Time.current.to_i
    base=group_payload(group,connection,notice_type:'group_msg_emoji_like',user_id:actor.external_id,message_id:target.external_id,likes:[{'emoji_id'=>'128169','count'=>1}])
    older=submit(base.merge('time'=>now,'is_add'=>true),connection)
    removal=submit(base.merge('time'=>now,'is_add'=>false),connection)
    Events::Processor.call(removal)
    Events::Processor.call(older)
    reaction=Interaction.find_by!(target_external_id:target.external_id,transporter:actor)
    refute reaction.active
    assert_equal removal.id,reaction.internal_event_id
    later=submit(base.merge('time'=>now+1,'is_add'=>true),connection)
    Events::Processor.call(later)
    assert reaction.reload.active
  end

  test 'older bot card and member events cannot restore superseded state' do
    group=domain_group
    connection=domain_bot(group)
    now=Time.current.to_i
    old_card=submit(group_payload(group,connection,notice_type:'group_card',user_id:connection.bot_account.external_id,card_new:'自助餐',time:now),connection)
    new_card=submit(group_payload(group,connection,notice_type:'group_card',user_id:connection.bot_account.external_id,card_new:'闭嘴',time:now+1),connection)
    Events::Processor.call(new_card)
    Events::Processor.call(old_card)
    assert group.reload.can_collect?
    assert group.can_distribute?
    assert_equal '闭嘴',group.group_bot_memberships.find_by!(bot_account:connection.bot_account).card
    person=domain_transporter
    joined=submit(group_payload(group,connection,notice_type:'group_increase',user_id:person.external_id,time:now),connection)
    left=submit(group_payload(group,connection,notice_type:'group_decrease',user_id:person.external_id,time:now+2),connection)
    admin=submit(group_payload(group,connection,notice_type:'group_admin',sub_type:'set',user_id:person.external_id,time:now+1),connection)
    [left,joined,admin].each { |event|Events::Processor.call(event) }
    refute GroupMember.find_by!(group:group,transporter:person).active
  end

  test 'delivery receipt backfills feedback received before the message row' do
    source=domain_group
    target=domain_group
    connection=domain_bot(target)
    entry=domain_entry(group:source,safety_level:'GREEN',visibility:'public',level:'NORMAL')
    delivery=Delivery.create!(shit_entry:entry,group:target,bot_connection:connection,kind:'BOT_DISTRIBUTION',status:'sending',idempotency_key:'early-receipt-test')
    actor=domain_transporter
    reaction=Interaction.create!(group:target,transporter:actor,target_external_id:'early-receipt',kind:'reaction',reaction:'💩',active:true,occurred_at:Time.current,identity_key:'early-feedback')
    Distributor.send(:complete_send!,delivery,'early-receipt',Time.current)
    assert_equal delivery.reload.message_id,reaction.reload.message_id
    assert_equal 1,entry.reload.interaction_count
  end

  test 'first contact confirms bot card and a later message does not resurrect removed membership' do
    group=domain_group
    connection=domain_bot
    adapter=Adapters::FakeNapCatAdapter.new(connection)
    payload=group_payload(group,connection,post_type:'message',message_type:'group',user_id:'first-person',message_id:'first-contact',message:[{'type'=>'text','data'=>{'text'=>'hello'}}])
    adapter.stub(:get_bot_card,'闭嘴') do
      Adapters::Registry.stub(:for,adapter) { Events::Processor.call(submit(payload,connection)) }
    end
    membership=group.group_bot_memberships.find_by!(bot_account:connection.bot_account)
    assert_equal '闭嘴',membership.card
    assert group.reload.can_collect?
    assert group.can_distribute?
    membership.update!(active:false)
    Events::Processor.call(submit(payload.merge('message_id'=>'late-contact','time'=>payload['time']-1),connection))
    refute membership.reload.active
  end

  test 'unconfirmed bot card does not disable default self service participation' do
    group=domain_group
    connection=domain_bot
    payload=group_payload(group,connection,post_type:'message',message_type:'group',user_id:'unknown-person',message_id:'unknown-contact',message:[{'type'=>'text','data'=>{'text'=>'hello'}}])
    Events::Processor.call(submit(payload,connection))
    assert group.reload.can_collect?
    assert group.can_distribute?
    assert_nil group.group_bot_memberships.find_by!(bot_account:connection.bot_account).card_event_at
  end

  test 'card updates from multiple bots cannot override saved group participation' do
    group=domain_group(collect_enabled:false,distribute_enabled:true)
    first=domain_bot(group)
    second=domain_bot(group)
    [first,second].each_with_index do |connection,index|
      event=submit(group_payload(group,connection,notice_type:'group_card',user_id:connection.bot_account.external_id,card_new:index.zero? ? '自助餐' : '搬💩'),connection)
      Events::Processor.call(event)
    end
    refute group.reload.can_collect?
    assert group.can_distribute?
    assert_equal [false,true],group.attributes.values_at('collect_enabled','distribute_enabled')
  end
end
