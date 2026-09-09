require_relative '../domain_helpers'

class SimulationTest < ActiveSupport::TestCase
  include DomainHelpers
  setup do
    @groups=10.times.map { domain_group(trial_preference:'OPT_IN') }
    @people=36.times.map { domain_transporter }
    @groups.each { |group| @people.each_with_index { |person,i| GroupMember.create!(group:group,transporter:person,role:i.zero? ? 'owner' : 'member') } }
    domain_bot(*@groups.first(5));domain_bot(*@groups.last(5))
    @user=domain_user(site_role:'curator')
    @run=SimulationRun.create!(user:@user,clock_at:Time.current)
  end
  def act(name)
    action=@run.simulation_actions.create!(action_name:name)
    SimulationActionJob.perform_now(action.id)
    assert_equal 'done',action.reload.status,"#{name}: #{action.result}"
    @run.reload
  end
  test 'fake QQ lifecycle uses real collector safety trials deliveries and natural revival' do
    AppConfig.with(trial:{group_min:3,group_max:3}) do
      act('image')
      assert_equal 'pending',@run.candidate.status
      assert_equal 0,ShitEntry.count
      act('replies');act('reaction')
      assert_equal 'pending',@run.candidate.reload.status
      act('evaluate')
      entry=@run.entry;sid=entry.sid
      assert_equal 'accepted',@run.candidate.status
      assert_equal 'RED',entry.safety_level
      assert_equal 0,Delivery.count
      act('approve');act('dispatch')
      assert_equal 3,Delivery.where(status:'sent',kind:'BOT_TRIAL').count
      assert_equal 1,entry.reload.natural_count
      act('feedback');act('finish')
      result=entry.latest_trial_result
      assert_equal 3,result.trial_group_count
      assert_equal 2,result.responsive_group_count
      assert_equal 1,result.bad_reactions
      assert_equal 'passed',result.verdict
      assert_equal 'NORMAL',entry.reload.level
      act('distribute')
      assert_operator entry.reload.bot_count,:>,3
      act('repeat')
      assert_equal sid,@run.entry.sid
      assert_equal 2,entry.reload.natural_count
      act('revive')
      assert_equal 1,ShitEntry.count
      assert_equal sid,entry.reload.sid
      assert_equal 'CLASSIC',entry.level
      assert_operator entry.revival_count,:>=,1
      assert entry.timeline_events.where(event_type:'revival').exists?
      assert entry.shit_occurrences.where(source:'BOT_TRIAL').exists?
      assert entry.shit_occurrences.where(source:'BOT_DISTRIBUTION').exists?
    end
  end
  test 'forward records become one permanent entry on a later natural reappearance' do
    act('forward');act('replies');act('evaluate')
    entry=@run.entry
    assert_equal 'forward',entry.content.kind
    assert_operator entry.content.forward_nodes.count,:>=,3
    act('repeat')
    assert_equal 1,ShitEntry.count
    assert_equal 2,entry.reload.natural_count
  end
end
