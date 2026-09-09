require_relative '../domain_helpers'
class MergeTest < ActiveSupport::TestCase
  include DomainHelpers
  test 'merge retains permanent IDs counts and can undo without safety downgrade' do
    curator=domain_user(site_role:'curator')
    source=domain_entry(safety_level:'RED');target=domain_entry(safety_level:'GREEN',visibility:'public')
    [source,target].each { |entry| OccurrenceRecorder.call(entry:entry,message:domain_message(group:entry.first_group,content:entry.content)) }
    ids=[source.sid,target.sid]
    merge=EntryMergeService.merge!(source:source,target:target,user:curator,reason:'确认是相同标本')
    assert_equal target,source.reload.merged_into
    assert_equal 2,target.reload.natural_count
    assert_equal 'RED',target.safety_level
    EntryMergeService.revert!(merge:merge,user:curator)
    assert_nil source.reload.merged_into
    assert_equal [1,1],[source.natural_count,target.reload.natural_count]
    assert_equal ids,[source.sid,target.sid]
    assert_equal 'RED',target.safety_level
    assert_raises(ArgumentError) { EntryMergeService.revert!(merge:merge,user:curator) }
  end
  test 'ordinary visitors and active trials cannot merge' do
    source=domain_entry;target=domain_entry
    assert_raises(ArgumentError) { EntryMergeService.merge!(source:source,target:target,user:domain_user,reason:'test') }
    TrialRun.create!(shit_entry:source,status:'pending')
    assert_raises(ArgumentError) { EntryMergeService.merge!(source:source,target:target,user:domain_user(site_role:'curator'),reason:'test') }
  end
end
