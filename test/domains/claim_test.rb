require_relative '../domain_helpers'
class ClaimTest < ActiveSupport::TestCase
  include DomainHelpers
  setup do
    @group=domain_group
    @connection=domain_bot(@group)
    @owner=domain_transporter;@member=domain_transporter
    GroupMember.create!(group:@group,transporter:@owner,role:'owner')
    GroupMember.create!(group:@group,transporter:@member,role:'member')
    @user=domain_user
    @claim,@token=ClaimIssuer.call(user:@user)
    @adapter=Adapters::Registry.for(@connection)
  end
  test 'fake OneBot claim verifies actual role and consumes token once without storing plaintext' do
    FakeQQEnvironment.new(group:@group,transporter:@owner).claim(token:@token)
    assert @claim.reload.used_at
    assert @user.manages?(@group)
    assert_equal 'owner',GroupManagement.find_by!(user:@user,group:@group).verified_role
    refute_includes RawEvent.last.payload.to_json,@token
    refute_includes InternalEvent.last.metadata.to_json,@token
    refute_includes Message.last.body,@token
    assert_no_difference('GroupManagement.count') { FakeQQEnvironment.new(group:@group,transporter:@owner).claim(token:@token) }
  end
  test 'expired and invalid tokens never authorize group management' do
    @claim.update!(expires_at:1.second.ago)
    result=ClaimVerifier.call(token:@token,group:@group,sender_external_id:@owner.external_id,adapter:@adapter,mentions_bot:true)
    refute result.success
    refute @user.manages?(@group)
    refute ClaimVerifier.call(token:'CLAIM-DOESNOTEXIST',group:@group,sender_external_id:@owner.external_id,adapter:@adapter,mentions_bot:true).success
    assert_nil @claim.reload.used_at
  end
  test 'ordinary members cannot claim and exceeding attempt limit blocks later reuse' do
    AppConfig.with(claim:{max_attempts:2}) do
      2.times { refute ClaimVerifier.call(token:@token,group:@group,sender_external_id:@member.external_id,adapter:@adapter,mentions_bot:true).success }
      assert_equal 2,@claim.reload.attempts
      refute ClaimVerifier.call(token:@token,group:@group,sender_external_id:@owner.external_id,adapter:@adapter,mentions_bot:true).success
      assert_equal 0,GroupManagement.count
    end
  end
  test 'claim requires explicit bot mention and is unrelated to site email' do
    refute ClaimVerifier.call(token:@token,group:@group,sender_external_id:@owner.external_id,adapter:@adapter,mentions_bot:false).success
    assert_nil @claim.reload.used_at
    assert_equal Digest::SHA256.hexdigest(@token),@claim.token_digest
    refute @user.respond_to?(:qq_number)
  end
end
