require_relative '../domain_helpers'

class CollectorDomainTest < ActiveSupport::TestCase
  include DomainHelpers
  include ActiveJob::TestHelper

  test 'a strong candidate remains pending until the full observation window' do
    travel_to Time.utc(2026, 1, 1, 12) do
      message = domain_message
      2.times { domain_interaction(message: message, kind: 'quote') }
      candidate = Collector.collect(message: message)
      assert_equal 'pending', candidate.status
      assert_nil candidate.shit_entry
      assert_equal 5.0, candidate.score
      CandidateEvaluator.call(candidate: candidate, now: message.sent_at + 1799)
      assert_equal 'pending', candidate.reload.status
      CandidateEvaluator.call(candidate: candidate, now: message.sent_at + 1800)
      assert_equal 'accepted', candidate.reload.status
      assert_equal 'RED', candidate.shit_entry.safety_level
      assert_equal 'hidden', candidate.shit_entry.visibility
      assert_equal 1, candidate.shit_entry.natural_count
      assert_equal 2, candidate.rule_results['unique_users']
      assert_equal candidate.id, Collector.collect(message: message).id
    end
  end

  test 'self replies and repeated reactions by one person cannot manufacture admission' do
    message = domain_message
    8.times { domain_interaction(message: message, transporter: message.transporter, kind: 'quote') }
    spammer = domain_transporter
    10.times { domain_interaction(message: message, transporter: spammer, kind: 'reaction', reaction: '💩') }
    candidate = Collector.collect(message: message)
    CandidateEvaluator.call(candidate: candidate, now: candidate.expires_at)
    assert_equal 'expired', candidate.reload.status
    assert_equal 1, candidate.rule_results['unique_users']
    assert_equal 1.5, candidate.rule_results['evidence_score']
    assert_nil candidate.shit_entry
  end

  test 'author reputation alone never admits a silent candidate' do
    author = domain_transporter(reputation_score: 1, accepted_count: 100, candidate_count: 100)
    candidate = Collector.collect(message: domain_message(transporter: author))
    CandidateEvaluator.call(candidate: candidate, now: candidate.expires_at)
    assert_equal 'expired', candidate.reload.status
    assert_equal 0, candidate.rule_results['unique_users']
  end

  test 'independent natural repetitions are strong evidence and each occurrence is retained' do
    travel_to Time.utc(2026, 1, 1, 12) do
      content = domain_content
      first = Collector.collect(message: domain_message(content: content))
      2.times { Collector.collect(message: domain_message(content: content, at: Time.current + 60)) }
      CandidateEvaluator.call(candidate: first, now: first.expires_at)
      assert_equal 'accepted', first.reload.status
      assert_equal 2, first.rule_results['repeat_users']
      Candidate.where(content: content).where.not(id: first.id).each { |candidate| CandidateEvaluator.call(candidate: candidate, now: candidate.expires_at) }
      assert_equal 1, ShitEntry.where(content: content).count
      assert_equal 3, first.shit_entry.reload.natural_count
    end
  end

  test 'a confirmed duplicate keeps the archive id and adds one natural occurrence idempotently' do
    entry = domain_entry
    message = domain_message(content: entry.content)
    candidate = Collector.collect(message: message)
    assert_equal 'duplicate', candidate.status
    assert_equal entry.id, candidate.shit_entry_id
    assert_equal 1, entry.reload.natural_count
    CandidateEvaluator.call(candidate: candidate)
    assert_equal 1, entry.reload.natural_count
  end

  test 'disabled collection and bot messages never create candidates' do
    assert_nil Collector.collect(message: domain_message(group: domain_group(collect_enabled: false)))
    assert_nil Collector.collect(message: domain_message(source: 'BOT_DISTRIBUTION'))
    assert_nil Collector.collect(message: domain_message(content: domain_content(kind: 'text')))
  end

  test 'interactions outside observation time and withdrawn reactions are excluded' do
    message = domain_message
    2.times { domain_interaction(message: message, kind: 'quote', at: message.sent_at + 1801) }
    2.times { domain_interaction(message: message, kind: 'reaction', reaction: '💩', active: false) }
    candidate = Collector.collect(message: message)
    CandidateEvaluator.call(candidate: candidate, now: candidate.expires_at + 500)
    assert_equal 'expired', candidate.reload.status
    assert_equal 0, candidate.rule_results['unique_users']
  end

  test 'reputation has neutral cold start and transparent smoothed numerator and denominator' do
    transporter = domain_transporter
    ReputationCalculator.call(transporter)
    assert_equal 0.5, transporter.reload.reputation_score
    assert_equal 0, transporter.candidate_count
    assert_equal 0, transporter.reputation_details['adjustment']
    assert_equal 6.0, transporter.reputation_details['posterior_denominator']
  end

  test 'raw candidate counts include pending observations but Bayesian samples exclude them' do
    transporter = domain_transporter
    %w[pending expired expired accepted].each do |status|
      message = domain_message(transporter: transporter)
      Candidate.create!(message: message, transporter: transporter, group: message.group, content: message.content, expires_at: Time.current, status: status)
    end
    ReputationCalculator.call(transporter)
    assert_equal 4, transporter.reload.candidate_count
    assert_equal 3, transporter.reputation_details['settled_samples']
    assert_equal 1, transporter.accepted_count
    assert_in_delta 4.0 / 9, transporter.reputation_score
    assert_equal 0, transporter.reputation_details['adjustment']
  end

  test 'a new pending candidate schedules the raw transporter statistics refresh' do
    transporter = domain_transporter
    perform_enqueued_jobs(only: ReputationRefreshJob) do
      Collector.collect(message: domain_message(transporter: transporter))
    end
    assert_equal 1, transporter.reload.candidate_count
    assert_equal 0, transporter.reputation_details['settled_samples']
    assert_equal 0.5, transporter.reputation_score
  end
end
