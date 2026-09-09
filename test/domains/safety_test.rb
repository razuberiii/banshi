require_relative '../domain_helpers'

class SafetyDomainTest < ActiveSupport::TestCase
  include DomainHelpers
  include ActiveJob::TestHelper

  test 'resuming a paused entry requires an explicit review with all reports closed and all restrictions satisfied' do
    entry=domain_entry(level:'NORMAL',safety_level:'GREEN',visibility:'public',distribution_paused:true)
    reviewer=domain_user(site_role:'curator')
    report=ReportService.create!(entry:entry,user:domain_user,reason:'other',details:'review')
    assert_raises(ArgumentError) { SafetyEvaluator.resume!(entry:entry,user:reviewer,reason:'checked') }
    assert entry.reload.distribution_paused
    ReportService.resolve!(report:report,reviewer:reviewer,status:'resolved',resolution:'checked')
    assert entry.reload.distribution_paused
    assert_raises(SecurityError) { SafetyEvaluator.resume!(entry:entry,user:domain_user,reason:'checked') }
    entry.update!(safety_level:'RED')
    assert_raises(ArgumentError) { SafetyEvaluator.resume!(entry:entry,user:reviewer,reason:'checked') }
    assert entry.reload.distribution_paused
    entry.update!(safety_level:'GREEN')
    assert_enqueued_with(job:DistributionJob,args:[entry.id]) do
      SafetyEvaluator.resume!(entry:entry,user:reviewer,reason:'所有举报已处理，复核原图与标签')
    end
    refute entry.reload.distribution_paused
    assert_equal 1,AuditLog.where(shit_entry:entry,action:'resume_distribution').count
  end

  test 'tagged content cannot use GREEN to bypass a groups appetite' do
    entry=domain_entry(safety_level:'GREEN',safety_tags:['NSFW'],visibility:'public')
    refute SafetyEvaluator.call(entry:entry,group:domain_group(accepted_tags:[])).allowed?
    decision=SafetyEvaluator.mark!(entry:entry,level:'GREEN',tags:['NSFW'],visibility:'public',reason:'explicit tag',user:domain_user(site_role:'curator'))
    assert_equal 'YELLOW',decision.level
  end

  test 'default red and a high quality score cannot bypass safety' do
    entry = domain_entry(level: 'HOT', distribution_score: 100)
    refute SafetyEvaluator.call(entry: entry).allowed?
    assert_empty TrialSelector.call(entry: entry, now: Time.current)
    assert_nil TrialDispatcher.call(entry: entry)
    assert_equal 0, entry.trial_runs.count
  end

  test 'yellow content requires every tag to be accepted and hard bans cannot be configured away' do
    entry = domain_entry(safety_level: 'YELLOW', visibility: 'public', safety_tags: %w[GORE GROTESQUE])
    group = domain_group(accepted_tags: %w[GORE])
    refute SafetyEvaluator.call(entry: entry, group: group).allowed?
    group.update!(accepted_tags: %w[GORE GROTESQUE])
    assert SafetyEvaluator.call(entry: entry, group: group).allowed?
    entry.update!(safety_tags: %w[PRIVACY])
    group.update!(accepted_tags: %w[PRIVACY])
    AppConfig.with(safety: { hard_block_tags: [] }) do
      refute SafetyEvaluator.call(entry: entry, group: group).allowed?
    end
  end

  test 'manual review creates safety and audit history and schedules a deferred safe trial' do
    entry = domain_entry
    candidate = Candidate.create!(message: domain_message(content: entry.content), content: entry.content, group: entry.first_group, transporter: entry.first_transporter, shit_entry: entry, status: 'accepted', expires_at: Time.current)
    assert_enqueued_with(job: TrialDispatchJob, args: [entry.id]) do
      SafetyEvaluator.mark!(entry: entry, level: 'GREEN', tags: [], visibility: 'public', reason: '人工确认原创示例', user: domain_user(site_role: 'curator'))
    end
    assert SafetyEvaluator.call(entry: entry.reload).allowed?
    assert_equal 1, entry.safety_decisions.count
    assert_equal 1, AuditLog.where(shit_entry: entry, category: 'safety').count
    assert_equal 'accepted', candidate.reload.status
  end

  test 'report thresholds count distinct reporters and pause before distribution' do
    entry = domain_entry(safety_level: 'GREEN', visibility: 'public')
    reporter = domain_user
    first = ReportService.create!(entry: entry, user: reporter, reason: 'other', details: '需复核')
    again = ReportService.create!(entry: entry, user: reporter, reason: 'other', details: '重复点击')
    assert_equal first.id, again.id
    2.times { ReportService.create!(entry: entry, user: domain_user, reason: 'other', details: '') }
    assert_equal 3, entry.reports.where(status: 'open').count
    assert entry.reload.distribution_paused
    refute SafetyEvaluator.call(entry: entry).allowed?
    assert_equal 'public', entry.visibility
  end

  test 'one privacy or minors report immediately hides media with an auditable decision' do
    %w[privacy minors].each do |reason|
      entry = domain_entry(safety_level: 'GREEN', visibility: 'public', level: 'CLASSIC')
      report = ReportService.create!(entry: entry, user: domain_user, reason: reason, details: '请隐藏')
      assert_equal 'hidden', entry.reload.visibility
      assert_equal 'RED', entry.safety_level
      assert entry.distribution_paused
      assert_equal 'report', entry.safety_decisions.last.source
      ReportService.resolve!(report: report, reviewer: domain_user(site_role: 'curator'), status: 'dismissed', resolution: '已复核')
      assert_equal 'dismissed', report.reload.status
      assert_equal 'hidden', entry.reload.visibility
    end
  end

  test 'urgent reports hide shared assets globally and dismissing a report never restores media' do
    asset = Asset.create!(sha256: SecureRandom.hex(32), storage_key: "shared-#{SecureRandom.hex(8)}.png", content_type: 'image/png', byte_size: 10)
    first = domain_entry(safety_level: 'GREEN', visibility: 'public')
    second = domain_entry(safety_level: 'GREEN', visibility: 'public')
    [first, second].each { |entry| Attachment.create!(content: entry.content, asset: asset) }
    report = ReportService.create!(entry: first, user: domain_user, reason: 'privacy', details: '共享图片需要隐藏')
    assert_equal 'hidden', asset.reload.visibility
    refute SafetyEvaluator.call(entry: second).allowed?
    ReportService.resolve!(report: report, reviewer: domain_user(site_role: 'curator'), status: 'dismissed', resolution: '转人工媒体复核')
    assert_equal 'hidden', asset.reload.visibility
  end

  test 'an existing reporter can escalate to privacy without becoming a second reporter' do
    entry = domain_entry(safety_level: 'GREEN', visibility: 'public')
    reporter = domain_user
    initial = ReportService.create!(entry: entry, user: reporter, reason: 'other', details: '需要复核')
    escalated = ReportService.create!(entry: entry, user: reporter, reason: 'privacy', details: '发现隐私信息')
    assert_equal initial.id, escalated.id
    assert_equal 1, entry.reports.where(status: 'open').count
    assert_equal 'privacy', escalated.reload.reason
    assert_equal 'hidden', entry.reload.visibility
    assert entry.distribution_paused
  end
end
