require_relative '../domain_helpers'

class TrialDistributionDomainTest < ActiveSupport::TestCase
  include DomainHelpers
  include ActiveJob::TestHelper

  test 'seat selection prioritizes opt in rotation and excludes opt out source natural and offline groups' do
    now = Time.current
    entry = domain_entry(safety_level: 'GREEN', visibility: 'public')
    OccurrenceRecorder.call(entry: entry, message: domain_message(content: entry.content, group: entry.first_group, at: entry.first_seen_at))
    older = domain_group(trial_preference: 'OPT_IN', last_trial_at: 3.days.ago)
    newer = domain_group(trial_preference: 'OPT_IN', last_trial_at: 1.day.ago)
    fresh = domain_group(trial_preference: 'OPT_IN')
    fallback = domain_group(trial_preference: 'FALLBACK')
    opt_out = domain_group(trial_preference: 'OPT_OUT')
    natural = domain_group(trial_preference: 'OPT_IN')
    offline = domain_group(trial_preference: 'OPT_IN')
    domain_bot(entry.first_group, older, newer, fresh, fallback, opt_out, natural)
    OccurrenceRecorder.call(entry: entry, message: domain_message(content: entry.content, group: natural))
    AppConfig.with(trial: { group_max: 4 }) do
      assert_equal [fresh.id, older.id, newer.id, fallback.id], TrialSelector.call(entry: entry, now: now).map(&:id)
    end
    refute GroupMatcher.call(entry: entry, group: offline, kind: 'BOT_TRIAL', now: now).allowed?
  end

  test 'insufficient eligible seats remain pending without a failed trial or archive verdict' do
    entry = domain_entry(safety_level: 'GREEN', visibility: 'public')
    domain_bot(domain_group(trial_preference: 'OPT_IN'))
    run = TrialDispatcher.call(entry: entry)
    assert_equal 'pending', run.status
    assert_equal 'waiting_for_groups', run.explanation['reason']
    assert_equal 'TRIAL', entry.reload.level
    assert_nil run.trial_result
    assert_empty run.deliveries
    assert_equal run.id, TrialDispatcher.call(entry: entry, now: Time.current + 2.days).id
    assert_equal 'pending', run.reload.status
  end

  test 'trial reserves unique durable seats and sends idempotently through the connected bot' do
    entry = domain_entry(safety_level: 'GREEN', visibility: 'public')
    groups = 3.times.map { domain_group(trial_preference: 'OPT_IN') }
    domain_bot(*groups)
    run = TrialDispatcher.call(entry: entry)
    assert_equal 'running', run.status
    assert_equal 3, run.deliveries.count
    run.deliveries.each { |delivery| Distributor.deliver!(delivery: delivery) }
    assert_equal 3, run.deliveries.where(status: 'sent').count
    assert_equal 3, entry.reload.bot_count
    assert_equal 0, entry.natural_count
    delivery = run.deliveries.first
    message_id = delivery.reload.message_id
    Distributor.deliver!(delivery: delivery)
    assert_equal message_id, delivery.reload.message_id
    assert_equal 3, entry.reload.bot_count
    assert groups.all? { |group| group.reload.last_trial_at.present? }
  end

  test 'silence is unknown and exposed rates retain their documented denominators' do
    now = Time.current
    entry = domain_entry(level: 'TRIAL', safety_level: 'GREEN', visibility: 'public')
    run = domain_sent_trial(entry: entry, groups: 3.times.map { domain_group }, at: now)
    message = run.deliveries.first.message
    domain_interaction(message: message, kind: 'reaction', reaction: '💩', at: now + 60)
    TrialEvaluator.call(run: run, now: run.ends_at)
    result = run.reload.trial_result
    assert_equal 3, result.trial_group_count
    assert_equal 1, result.responsive_group_count
    assert_equal 1, result.good_reactions
    assert_equal 0, result.bad_reactions
    assert_in_delta 1.0 / 3, result.positive_rate
    assert_in_delta 1.0 / 3, result.responsive_group_rate
    assert_equal 0, result.negative_rate
    assert_equal 'passed', result.verdict
    assert_equal 2, run.trial_deliveries.where(feedback_state: 'unknown').count
    assert_equal 'NORMAL', entry.reload.level
    TrialEvaluator.call(run: run, now: run.ends_at + 1)
    assert_equal 1, TrialResult.where(trial_run: run).count
  end

  test 'explicit bad reactions are negative while duplicate replies count unique people' do
    now = Time.current
    entry = domain_entry(level: 'TRIAL', safety_level: 'GREEN', visibility: 'public')
    run = domain_sent_trial(entry: entry, groups: [domain_group], at: now)
    message = run.deliveries.first.message
    spammer = domain_transporter
    5.times { domain_interaction(message: message, transporter: spammer, kind: 'reply', at: now + 1) }
    domain_interaction(message: message, kind: 'reaction', reaction: '🥱', at: now + 2)
    domain_interaction(message: message, kind: 'reaction', reaction: '💩', at: now + 3, active: false)
    TrialEvaluator.call(run: run, now: run.ends_at)
    result = run.reload.trial_result
    assert_equal 1, result.unique_reply_users
    assert_equal 2, result.unique_interaction_users
    assert_equal 1, result.bad_reactions
    assert_equal 1.0, result.negative_rate
    assert_equal 'failed', result.verdict
    assert_equal 'ARCHIVED', entry.reload.level
    assert_equal 'negative', run.trial_deliveries.first.feedback_state
  end

  test 'all silent trials archive as unknown and cannot be evaluated before the deadline' do
    entry = domain_entry(level: 'TRIAL', safety_level: 'GREEN', visibility: 'public')
    run = domain_sent_trial(entry: entry, groups: [domain_group])
    TrialEvaluator.call(run: run, now: run.ends_at - 1)
    assert_nil run.reload.trial_result
    TrialEvaluator.call(run: run, now: run.ends_at)
    assert_equal 'unknown', run.reload.trial_result.verdict
    assert_equal 0, run.trial_result.negative_rate
    assert_equal 'ARCHIVED', entry.reload.level
  end

  test 'source author cannot boost a trial and two other reply users can make a group positive' do
    now = Time.current
    entry = domain_entry(level: 'TRIAL', safety_level: 'GREEN', visibility: 'public')
    run = domain_sent_trial(entry: entry, groups: [domain_group], at: now)
    message = run.deliveries.first.message
    5.times { domain_interaction(message: message, transporter: entry.first_transporter, kind: 'reaction', reaction: '💩', at: now + 1) }
    2.times { domain_interaction(message: message, kind: 'reply', at: now + 1) }
    TrialEvaluator.call(run: run, now: run.ends_at)
    result = run.reload.trial_result
    assert_equal 0, result.good_reactions
    assert_equal 2, result.unique_reply_users
    assert_equal 1.0, result.positive_rate
    assert_equal 'passed', result.verdict
  end

  test 'safety is rechecked after reservation before a send' do
    entry = domain_entry(safety_level: 'GREEN', visibility: 'public', level: 'NORMAL')
    group = domain_group
    domain_bot(group)
    delivery = Distributor.call(entry: entry).first
    entry.update!(safety_level: 'RED', visibility: 'hidden')
    Distributor.deliver!(delivery: delivery)
    assert_equal 'cancelled', delivery.reload.status
    assert_nil delivery.message_id
    assert_equal 0, entry.reload.bot_count
  end

  test 'uncertain sends are durable and are never retried blindly' do
    entry = domain_entry(safety_level: 'GREEN', visibility: 'public', level: 'NORMAL')
    group = domain_group
    domain_bot(group)
    delivery = Distributor.call(entry: entry).first
    adapter = Object.new
    adapter.define_singleton_method(:send_content) { |**_| raise Adapters::OneBotAdapter::AmbiguousDelivery, 'response timeout' }
    Adapters::Registry.stub(:for, adapter) { Distributor.deliver!(delivery: delivery) }
    assert_equal 'uncertain', delivery.reload.status
    refute_nil delivery.error_message
    Distributor.deliver!(delivery: delivery)
    assert_equal 'uncertain', delivery.reload.status
    assert_nil delivery.message_id
  end

  test 'pending reservations enforce group daily quota and global minute limit across entries' do
    now = Time.current
    group = domain_group(daily_limit: 1, cooldown_minutes: 0)
    domain_bot(group)
    first = domain_entry(safety_level: 'GREEN', visibility: 'public', level: 'NORMAL')
    second = domain_entry(safety_level: 'GREEN', visibility: 'public', level: 'NORMAL')
    assert_equal 1, Distributor.call(entry: first, now: now).length
    assert_empty Distributor.call(entry: second, now: now)
    other = domain_group(cooldown_minutes: 0)
    domain_bot(other)
    AppConfig.with(distribution: { global_per_minute: 1 }) do
      assert_empty Distributor.call(entry: second, now: now)
    end
  end

  test 'pending delivery resumes safely and successful delivery applies group cooldown' do
    now = Time.current
    group = domain_group(cooldown_minutes: 60)
    domain_bot(group)
    entry = domain_entry(safety_level: 'GREEN', visibility: 'public', level: 'NORMAL')
    delivery = Distributor.call(entry: entry, now: now).first
    Distributor.deliver!(delivery: delivery, now: now)
    other = domain_entry(safety_level: 'GREEN', visibility: 'public', level: 'NORMAL')
    assert_empty Distributor.call(entry: other, now: now + 3599)
    assert_equal 1, Distributor.call(entry: other, now: now + 3600).size
  end

  test 'a worker restart during sending becomes uncertain instead of sending twice' do
    entry = domain_entry(safety_level: 'GREEN', visibility: 'public', level: 'NORMAL')
    domain_bot(domain_group)
    delivery = Distributor.call(entry: entry).first
    delivery.update!(status: 'sending')
    Distributor.deliver!(delivery: delivery)
    assert_equal 'uncertain', delivery.reload.status
    assert_nil delivery.message_id
    assert_equal 0, entry.reload.bot_count
  end

  test 'classic archaeology requires explicit opt in and the complete repeat delay' do
    now = Time.current
    group = domain_group(accept_archaeology: false, cooldown_minutes: 0)
    domain_bot(group)
    entry = domain_entry(group: group, safety_level: 'GREEN', visibility: 'public', level: 'CLASSIC', at: now - 91.days)
    OccurrenceRecorder.call(entry: entry, message: domain_message(group: group, content: entry.content, at: now - 91.days))
    refute GroupMatcher.call(entry: entry, group: group, kind: 'BOT_CLASSIC', now: now).allowed?
    group.update!(accept_archaeology: true)
    assert GroupMatcher.call(entry: entry, group: group, kind: 'BOT_CLASSIC', now: now).allowed?
    delivery = Distributor.call(entry: entry, now: now).first
    Distributor.deliver!(delivery: delivery, now: now)
    assert_equal 'BOT_CLASSIC', delivery.kind
    refute GroupMatcher.call(entry: entry, group: group, kind: 'BOT_CLASSIC', now: now + 89.days).allowed?
    assert GroupMatcher.call(entry: entry, group: group, kind: 'BOT_CLASSIC', now: now + 90.days).allowed?
    refute GroupMatcher.call(entry: entry, group: group, kind: 'BOT_TRIAL', now: now + 90.days).allowed?
  end

  test 'global reservations release the minute window at its exact boundary' do
    now = Time.utc(2026, 1, 1, 12)
    groups = 2.times.map { domain_group(cooldown_minutes: 0) }
    domain_bot(*groups)
    first = domain_entry(safety_level: 'GREEN', visibility: 'public', level: 'NORMAL')
    second = domain_entry(safety_level: 'GREEN', visibility: 'public', level: 'NORMAL')
    AppConfig.with(distribution: { global_per_minute: 1, batch_size: 1 }) do
      assert_equal 1, Distributor.call(entry: first, now: now).length
      assert_empty Distributor.call(entry: second, now: now + 59)
      assert_equal 1, Distributor.call(entry: second, now: now + 60).length
    end
  end

  test 'zero group quota and zero batch limit reserve no outbound messages' do
    group = domain_group(daily_limit: 0)
    domain_bot(group)
    entry = domain_entry(safety_level: 'GREEN', visibility: 'public', level: 'NORMAL')
    assert_empty Distributor.call(entry: entry)
    group.update!(daily_limit: 5)
    AppConfig.with(distribution: { batch_size: 0 }) { assert_empty Distributor.call(entry: entry) }
    assert_equal 0, entry.deliveries.count
  end

  test 'a known transport rejection can retry the same durable delivery safely' do
    entry = domain_entry(safety_level: 'GREEN', visibility: 'public', level: 'NORMAL')
    domain_bot(domain_group)
    delivery = Distributor.call(entry: entry).first
    adapter = Object.new
    adapter.define_singleton_method(:send_content) { |**_| raise Adapters::OneBotAdapter::RemoteError, 'not sent' }
    assert_raises(Adapters::OneBotAdapter::RemoteError) do
      Adapters::Registry.stub(:for, adapter) { Distributor.deliver!(delivery: delivery) }
    end
    assert_equal 'failed', delivery.reload.status
    key = delivery.idempotency_key
    Distributor.deliver!(delivery: delivery)
    assert_equal 'sent', delivery.reload.status
    assert_equal key, delivery.idempotency_key
    assert_equal 1, entry.reload.bot_count
  end

  test 'a receipt survives a local persistence failure and the send becomes uncertain' do
    group = domain_group(cooldown_minutes: 0)
    domain_bot(group)
    previous = domain_entry(safety_level: 'GREEN', visibility: 'public')
    previous_message = domain_message(group: group, content: previous.content)
    OccurrenceRecorder.call(entry: previous, message: previous_message)
    entry = domain_entry(safety_level: 'GREEN', visibility: 'public', level: 'NORMAL')
    delivery = Distributor.call(entry: entry).first
    adapter = Object.new
    receipt = previous_message.external_id
    adapter.define_singleton_method(:send_content) { |**_| receipt }
    assert_raises(ArgumentError) do
      Adapters::Registry.stub(:for, adapter) { Distributor.deliver!(delivery: delivery) }
    end
    assert_equal 'uncertain', delivery.reload.status
    assert_equal receipt, delivery.external_message_id
    assert_equal previous.content_id, previous_message.reload.content_id
    assert_equal 'NATURAL', previous_message.source
    Distributor.deliver!(delivery: delivery)
    assert_nil delivery.reload.message_id
  end

  test 'a conflicting receipt never overwrites an unarchived natural message' do
    group=domain_group(cooldown_minutes:0)
    domain_bot(group)
    original=domain_message(group:group)
    entry=domain_entry(safety_level:'GREEN',visibility:'public',level:'NORMAL')
    delivery=Distributor.call(entry:entry).first
    receipt=original.external_id
    adapter=Object.new
    adapter.define_singleton_method(:send_content) { |**_|receipt }
    assert_raises(ArgumentError) { Adapters::Registry.stub(:for,adapter) { Distributor.deliver!(delivery:delivery) } }
    assert_equal 'uncertain',delivery.reload.status
    assert_equal receipt,delivery.external_message_id
    assert_equal 'NATURAL',original.reload.source
    refute_nil original.transporter_id
    refute_equal entry.content_id,original.content_id
    assert_nil original.shit_occurrence
  end
end
