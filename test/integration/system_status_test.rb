require_relative '../domain_helpers'
class SystemStatusTest < ActionDispatch::IntegrationTest
  include DomainHelpers
  test 'status requires maintainer authentication and stays usable without QQ' do
    get system_status_path
    assert_redirected_to login_path
    user = domain_user
    post login_path, params: {email: user.email, password: 'Domain-tests-2026!'}
    get system_status_path
    assert_response :forbidden
    user.update!(site_role: 'curator')
    get system_status_path
    assert_response :success
    assert_select 'h1', 'System status'
    assert_select 'dd', text: 'DISABLED'
  end
end
