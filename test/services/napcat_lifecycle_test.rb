require_relative '../domain_helpers'
class NapcatLifecycleTest < ActiveSupport::TestCase
  include DomainHelpers
  test 'login discovers account groups and roles without database setup' do
    adapter = Minitest::Mock.new
    adapter.expect(:get_login_info, {'user_id'=>123456, 'nickname'=>'Bot'})
    adapter.expect(:get_group_list, [{'group_id'=>654321}])
    adapter.expect(:get_group_member_info, {'role'=>'admin','card'=>''}, group_external_id: '654321', user_external_id: '123456')
    connection = NapcatLifecycle.sync!(name: 'primary', endpoint: 'http://napcat:3000', adapter: adapter)
    assert_equal '123456', connection.bot_account.external_id
    assert_equal 'online', connection.status
    group = Group.find_by!(external_id: '654321')
    assert group.can_collect?
    assert group.can_distribute?
    assert_equal 'admin', group.group_bot_memberships.first.role
    adapter.verify
  end

  test 'unavailable login is an ordinary waiting state and disables old connection' do
    connection = domain_bot(domain_group)
    connection.update!(adapter: 'real', name: 'primary', endpoint: 'http://napcat:3000')
    adapter = Object.new
    def adapter.get_login_info = raise Adapters::OneBotAdapter::RemoteError, 'not logged in'
    assert_nil NapcatLifecycle.sync!(name: 'primary', endpoint: connection.endpoint, adapter: adapter)
    assert_equal 'offline', connection.reload.status
  end
end
