require_relative '../domain_helpers'

class GroupPreferencesTest < ActiveSupport::TestCase
  include DomainHelpers

  test 'new groups persist explicit self service defaults without requiring a claim' do
    group=domain_group
    assert_equal true,group.reload.collect_enabled
    assert_equal true,group.distribute_enabled
    assert_empty group.group_managements
    assert Collector.collect(message:domain_message(group:group)).pending?
    domain_bot(group)
    entry=domain_entry(safety_level:'GREEN',visibility:'public',level:'NORMAL')
    assert GroupMatcher.call(entry:entry,group:group,kind:'BOT_DISTRIBUTION').allowed?
  end

  test 'participation switches are independent and reject ambiguous empty settings' do
    group=domain_group(collect_enabled:false,distribute_enabled:true)
    refute group.can_collect?
    assert group.can_distribute?
    group.assign_attributes(collect_enabled:nil)
    refute group.valid?
    assert group.errors[:collect_enabled].any?
  end
end
