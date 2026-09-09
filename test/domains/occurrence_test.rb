require_relative '../domain_helpers'

class OccurrenceDomainTest < ActiveSupport::TestCase
  include DomainHelpers

  test 'chronological natural gaps recompute revivals correctly after out of order ingestion' do
    start = Time.utc(2025, 1, 1)
    entry = domain_entry(at: start)
    messages = [0, 80, 40].map { |days| domain_message(content: entry.content, at: start + days.days) }
    [messages[1], messages[0], messages[2]].each { |message| OccurrenceRecorder.call(entry: entry, message: message) }
    assert_equal 3, entry.reload.natural_count
    assert_equal 3, entry.natural_group_count
    assert_equal 2, entry.revival_count
    assert_equal start, entry.first_seen_at
    assert_equal start + 80.days, entry.last_natural_at
    assert_equal 1, entry.shit_occurrences.where(first_appearance: true).count
    assert_equal messages[0].id, entry.shit_occurrences.find_by!(first_appearance: true).message_id
    OccurrenceRecorder.call(entry: entry, message: messages[0])
    assert_equal 3, entry.reload.natural_count
    assert_equal 3, entry.timeline_events.where(event_type: 'natural_occurrence').count
  end

  test 'bot delivery never increases natural counts lifespan or revival metrics' do
    start = Time.utc(2025, 1, 1)
    entry = domain_entry(at: start)
    natural = domain_message(content: entry.content, at: start)
    OccurrenceRecorder.call(entry: entry, message: natural)
    bot = domain_message(content: entry.content, source: 'BOT_CLASSIC', at: start + 120.days)
    OccurrenceRecorder.call(entry: entry, message: bot, source: 'BOT_CLASSIC')
    assert_equal 1, entry.reload.natural_count
    assert_equal 1, entry.bot_count
    assert_equal 0, entry.revival_count
    assert_equal 0, entry.lifespan_days
    assert_raises(ArgumentError) { OccurrenceRecorder.call(entry: entry, message: bot, source: 'NATURAL') }
  end

  test 'late natural observations remove revival events whose gaps no longer exist' do
    start = Time.utc(2025, 1, 1)
    entry = domain_entry(at: start)
    [0, 80].each { |day| OccurrenceRecorder.call(entry: entry, message: domain_message(content: entry.content, at: start + day.days)) }
    assert_equal 1, entry.reload.revival_count
    [20, 40, 60].each { |day| OccurrenceRecorder.call(entry: entry, message: domain_message(content: entry.content, at: start + day.days)) }
    assert_equal 0, entry.reload.revival_count
    assert_equal 0, entry.timeline_events.where(event_type: 'revival').count
  end

  test 'classic uses independent natural counts groups age and revival only' do
    start = Time.utc(2025, 1, 1)
    entry = domain_entry(at: start, level: 'NORMAL', distribution_score: 999)
    groups = 3.times.map { domain_group }
    [0, 1, 2, 3, 4, 5, 6, 100].each_with_index do |day, index|
      OccurrenceRecorder.call(entry: entry, message: domain_message(content: entry.content, group: groups[index % 3], at: start + day.days))
    end
    ClassicEvaluator.call(entry, now: start + 100.days)
    assert_equal 'CLASSIC', entry.reload.level
    assert_not_nil entry.classic_at
    assert_equal 1, entry.timeline_events.where(event_type: 'classic').count
    ClassicEvaluator.call(entry, now: start + 101.days)
    assert_equal 1, entry.timeline_events.where(event_type: 'classic').count

    artificial = domain_entry(at: start, level: 'HOT', distribution_score: 999)
    10.times { OccurrenceRecorder.call(entry: artificial, message: domain_message(content: artificial.content, source: 'BOT_DISTRIBUTION', at: start + 100.days), source: 'BOT_DISTRIBUTION') }
    ClassicEvaluator.call(artificial, now: start + 100.days)
    assert_equal 'HOT', artificial.reload.level
  end

  test 'hot promotion and cooling use measured recent natural activity' do
    now = Time.utc(2026, 1, 1)
    entry = domain_entry(at: now, level: 'NORMAL')
    5.times { |i| OccurrenceRecorder.call(entry: entry, message: domain_message(content: entry.content, at: now - i.hours)) }
    LevelEvaluator.call(entry, now: now)
    assert_equal 'HOT', entry.reload.level
    LevelEvaluator.call(entry, now: now + 8.days)
    assert_equal 'NORMAL', entry.reload.level
    assert_equal 'RED', entry.safety_level
  end

  test 'classic cannot substitute high popularity for missing groups or a missing revival gap' do
    start = Time.utc(2025, 1, 1)
    single_group = domain_entry(at: start, level: 'NORMAL', distribution_score: 999)
    [0, 1, 2, 3, 4, 5, 6, 100].each do |day|
      OccurrenceRecorder.call(entry: single_group, message: domain_message(content: single_group.content, group: single_group.first_group, at: start + day.days))
    end
    ClassicEvaluator.call(single_group, now: start + 200.days)
    assert_equal 'NORMAL', single_group.reload.level
    assert_equal 1, single_group.natural_group_count

    no_revival = domain_entry(at: start, level: 'NORMAL', distribution_score: 999)
    8.times do |index|
      OccurrenceRecorder.call(entry: no_revival, message: domain_message(content: no_revival.content, at: start + (index * 15).days))
    end
    ClassicEvaluator.call(no_revival, now: start + 200.days)
    assert_equal 'NORMAL', no_revival.reload.level
    assert_equal 0, no_revival.revival_count
  end
end
