require_relative '../domain_helpers'

class StatisticsDomainTest < ActiveSupport::TestCase
  include DomainHelpers

  test 'weekly reach counts distinct recent groups and excludes old and future activity' do
    now=Time.current
    entry=domain_entry(safety_level:'GREEN',visibility:'public')
    first=entry.first_group
    old=domain_group
    future=domain_group
    [[first,now-2.hours],[first,now-1.hour],[old,now-8.days],[future,now+1.day]].each do |group,at|
      OccurrenceRecorder.call(entry:entry,message:domain_message(group:group,content:entry.content,at:at))
    end
    metrics=ArchivePeriodMetrics.call(now:now)
    assert_equal 1,metrics[:reach][entry.id]
    assert_equal 2,metrics[:natural][entry.id]
  end

  test 'group statistics derive natural discoveries and bot visits separately' do
    group = domain_group
    entry = domain_entry(group: group)
    OccurrenceRecorder.call(entry: entry, message: domain_message(group: group, content: entry.content))
    OccurrenceRecorder.call(entry: entry, message: domain_message(group: group, content: entry.content, source: 'BOT_TRIAL'), source: 'BOT_TRIAL')
    GroupStatsRefresh.call(group)
    assert_equal 1, group.reload.stats['natural_occurrences']
    assert_equal 1, group.stats['bot_occurrences']
    assert_equal 1, group.stats['discoveries']
  end

  test 'leaderboards exclude hidden entries groups and private transporter profiles' do
    public_entry = domain_entry(safety_level: 'GREEN', visibility: 'public', level: 'NORMAL')
    hidden = domain_entry(safety_level: 'GREEN', visibility: 'public', group: domain_group(visibility: 'hidden'), distribution_score: 1000)
    OccurrenceRecorder.call(entry: public_entry, message: domain_message(content: public_entry.content, group: public_entry.first_group))
    OccurrenceRecorder.call(entry: hidden, message: domain_message(content: hidden.content, group: hidden.first_group))
    snapshots = LeaderboardRefresh.call
    assert snapshots.any?
    entry_ids = LeaderboardSnapshot.where(board: %w[fastest natural]).flat_map { |snapshot| snapshot.rows.map { |row| row['id'] } }
    assert_includes entry_ids, public_entry.id
    refute_includes entry_ids, hidden.id
    assert_equal 1, LeaderboardSnapshot.where(board: 'fastest').count
    LeaderboardRefresh.call
    assert_equal 1, LeaderboardSnapshot.where(board: 'fastest').count
  end
end
