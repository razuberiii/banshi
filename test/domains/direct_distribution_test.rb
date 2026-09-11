require_relative '../domain_helpers'

class DirectDistributionTest < ActiveSupport::TestCase
  include DomainHelpers
  include ActiveJob::TestHelper

  test 'ordinary candidates become distributable without trial approval' do
    message = domain_message(at: 10.minutes.ago)
    candidate = Candidate.create!(message: message, group: message.group, transporter: message.transporter,
      content: message.content, expires_at: 1.minute.ago)
    domain_interaction(message: message, at: message.sent_at + 30)
    CandidateEvaluator.call(candidate: candidate)
    assert_equal 'accepted', candidate.reload.status
    assert_equal 'NORMAL', candidate.shit_entry.level
    assert SafetyEvaluator.call(entry: candidate.shit_entry).allowed?
    assert_enqueued_with(job: DistributionJob, args: [candidate.shit_entry_id])
  end

  test 'direct distribution is the default and ordinary unknown media is visible' do
    config = AppConfig.load({})
    refute config.trial.required_before_distribution
    assert_equal 'GREEN', config.safety.default_level
    assert_equal 'public', config.safety.default_visibility
  end

  test 'optional trial silence never demotes an active entry' do
    now = Time.current
    entry = domain_entry(level: 'NORMAL', safety_level: 'GREEN', visibility: 'public')
    run = domain_sent_trial(entry: entry, groups: [domain_group], at: now)
    TrialEvaluator.call(run: run, now: run.ends_at)
    assert_equal 'unknown', run.reload.trial_result.verdict
    assert_equal 'NORMAL', entry.reload.level
  end
  test 'rounds wait for feedback and silence stays unknown' do
    now = Time.current
    entry = domain_entry(level: 'NORMAL', safety_level: 'GREEN', visibility: 'public')
    groups = 5.times.map { domain_group }
    domain_bot(*groups)
    first = Distributor.call(entry: entry, now: now)
    assert_equal 3, first.length
    first.each { |delivery| Distributor.deliver!(delivery: delivery, now: now) }
    assert_empty Distributor.call(entry: entry, now: now + 30)
    assert_equal 'unknown', DistributionFeedback.call(entry: entry).fetch(:state)
    assert_empty Distributor.call(entry: entry, now: now + 20.minutes)
    domain_interaction(message: first.first.reload.message, kind: 'reaction', reaction: '😂', at: now + 60)
    assert_equal 2, Distributor.call(entry: entry, now: now + 20.minutes).length
  end

  test 'an optional trial reservation cannot hold up the first distribution round' do
    entry = domain_entry(level: 'NORMAL', safety_level: 'GREEN', visibility: 'public')
    early = domain_group(trial_preference: 'OPT_IN')
    receivers = 3.times.map { domain_group(trial_preference: 'OPT_OUT') }
    domain_bot(early, *receivers)
    run = TrialDispatcher.call(entry: entry)
    assert_equal 'running', run.status
    assert_equal 'NORMAL', entry.reload.level
    assert_equal 3, Distributor.call(entry: entry).length
  end

end
