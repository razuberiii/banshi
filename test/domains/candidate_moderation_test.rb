require_relative '../domain_helpers'
class CandidateModerationTest < ActiveSupport::TestCase
  include DomainHelpers
  test 'explicit rejection stops admission and retains auditable reason' do
    candidate=Collector.collect(message:domain_message)
    curator=domain_user(site_role:'curator')
    CandidateModeration.call(candidate:candidate,user:curator,status:'rejected',reason:'重复垃圾消息')
    CandidateEvaluator.call(candidate:candidate,now:candidate.expires_at+1)
    assert_equal 'rejected',candidate.reload.status
    assert_nil candidate.shit_entry_id
    assert AuditLog.exists?(category:'collector',action:'candidate_disposition')
  end
  test 'candidate safety isolation requires curator authority' do
    candidate=Collector.collect(message:domain_message)
    assert_raises(ArgumentError) { CandidateModeration.call(candidate:candidate,user:domain_user,status:'unsafe',reason:'明确安全问题') }
    CandidateModeration.call(candidate:candidate,user:domain_user(site_role:'curator'),status:'unsafe',reason:'明确安全问题')
    assert_equal 'unsafe',candidate.reload.status
    assert_raises(ArgumentError) { CandidateModeration.call(candidate:candidate,user:domain_user(site_role:'curator'),status:'rejected',reason:'再次处理') }
  end
end
